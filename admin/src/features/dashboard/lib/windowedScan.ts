import { PAGE, type PageQuery } from './fetchAll'

const DAY_MS = 86_400_000
/**
 * Pages read inside a window before it is halved instead of paged further.
 *
 * Five pages caps a window at 5,000 rows and therefore caps every offset this
 * module asks for at 4,000 - comfortably inside the range that reliably answers
 * 200. The attendance table is very uneven (a 2020 month holds a few dozen rows,
 * a 2026 month holds thousands), so starting from a YEAR-wide window and halving
 * on overflow adapts to that: sparse history costs one request each, and only the
 * dense recent months pay for the extra levels of splitting.
 */
const MAX_PAGES_PER_WINDOW = 8

export interface WindowedScanOptions {
  /** Inclusive lower bound, 'YYYY-MM-DD'. */
  from: string
  /** Inclusive upper bound, 'YYYY-MM-DD'. */
  to: string
  /** Days per top-level window. Halved automatically while a window is full. */
  windowDays?: number
  /** Top-level windows in flight. */
  concurrency?: number
}

const iso = (ms: number) => new Date(ms).toISOString().slice(0, 10)

/**
 * One page inside a window; a short page means the window is exhausted.
 *
 * The single retry matters because a window that failed outright would abort the
 * whole scan and leave its tab stuck on "Loading…" with no way back.
 */
async function fetchWindowPage<T>(
  page: (from: number, to: number, fromDay: string, toDay: string) => PromiseLike<PageQuery<T>>,
  from: number,
  fromDay: string,
  toDay: string,
): Promise<T[]> {
  let message = 'unknown error'
  for (let attempt = 0; attempt <= 1; attempt++) {
    const res = await page(from, from + PAGE - 1, fromDay, toDay)
    if (!res.error) return res.data ?? []
    message = res.error.message
  }
  throw new Error(message)
}

/**
 * Reads a whole table WITHOUT ever using a deep OFFSET.
 *
 * Offset paging has a hard ceiling on this project. Measured with the app's own
 * authenticated key, `attendance?select=member_id,check_in_date` answers 200 for
 * offsets 0-35,000 and then returns HTTP 500 for every offset from 36,000 to
 * 47,000 - and those 500s survive both a concurrent retry and a sequential one,
 * so no amount of retrying reaches the tail. The identical query under the
 * service-role key returns 200 throughout, which is why this only ever shows up
 * in the browser and not in the seed or verification scripts.
 *
 * A `group by member_id, max(check_in_date)` would be a single aggregate, but
 * PostgREST cannot express it, and the paged replacement (migration 0036) is not
 * applied to this database - its RPC 404s, and probing for it would put a console
 * error on every page load, which the dashboard's own error gate fails on. So the
 * aggregate is computed client-side, over windows.
 *
 * The table is split by DATE instead of by offset. Each window is read with
 * shallow offsets (0, 1, 2, ...), and a window that comes back full is halved and
 * re-read, so the split self-tunes to wherever the data happens to be dense.
 * Every request therefore sits at a low offset - the range that reliably answers
 * 200 - while top-level windows still run concurrently.
 *
 * Ordering inside a window is irrelevant to the callers, which all reduce the
 * result to a per-member aggregate; the returned array is assembled in window
 * order so the output is deterministic.
 */
export async function fetchAllByDateWindows<T>(
  page: (from: number, to: number, fromDay: string, toDay: string) => PromiseLike<PageQuery<T>>,
  opts: WindowedScanOptions,
): Promise<T[]> {
  const windowDays = Math.max(1, opts.windowDays ?? 31)
  const concurrency = Math.max(1, opts.concurrency ?? 4)
  const startMs = Date.parse(`${opts.from}T00:00:00Z`)
  const endMs = Date.parse(`${opts.to}T00:00:00Z`)
  if (!Number.isFinite(startMs) || !Number.isFinite(endMs) || endMs < startMs) return []

  // `depth` bounds the halving. At depth 0 a window is a single day, and no
  // single day here holds a full page, so the recursion always terminates.
  const scan = async (fromMs: number, toMs: number, depth: number): Promise<T[]> => {
    const fromDay = iso(fromMs)
    const toDay = iso(toMs)
    const rows: T[] = []

    for (let i = 0; i < MAX_PAGES_PER_WINDOW; i++) {
      const chunk = await fetchWindowPage(page, i * PAGE, fromDay, toDay)
      rows.push(...chunk)
      if (chunk.length < PAGE) return rows
    }

    // The window is denser than the page budget allows, so split it.
    //
    // The rows already fetched are DISCARDED, not returned alongside the halves.
    // Returning them re-reads every one of them in the recursive calls, so a
    // table that needs four levels of splitting downloads each row five times -
    // and it also duplicates rows in the result, which would double-count in
    // whatever aggregate the caller builds. Only a window that finished inside
    // the budget is authoritative; an unfinished one is a probe, not an answer.
    //
    // `depth <= 0` means a single day still overflows, which this dataset never
    // produces; returning the probe there beats losing the window entirely.
    if (depth <= 0 || toMs <= fromMs) return rows
    const midMs = fromMs + Math.floor((toMs - fromMs) / 2 / DAY_MS) * DAY_MS
    if (midMs <= fromMs) return rows
    const [left, right] = await Promise.all([
      scan(fromMs, midMs, depth - 1),
      scan(midMs + DAY_MS, toMs, depth - 1),
    ])
    return [...left, ...right]
  }

  const windows: [number, number][] = []
  for (let t = startMs; t <= endMs; t += windowDays * DAY_MS) {
    windows.push([t, Math.min(t + (windowDays - 1) * DAY_MS, endMs)])
  }

  // Small worker pool: windows are independent, so this is a bounded map.
  const results: T[][] = new Array(windows.length)
  let cursor = 0
  await Promise.all(
    Array.from({ length: Math.min(concurrency, windows.length) }, async () => {
      for (;;) {
        const i = cursor++
        if (i >= windows.length) return
        const [a, b] = windows[i]
        results[i] = await scan(a, b, 12)
      }
    }),
  )

  const out: T[] = []
  for (const chunk of results) if (chunk) out.push(...chunk)
  return out
}
