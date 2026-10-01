/**
 * PostgREST returns at most 1000 rows per request unless `.limit()` says
 * otherwise, and the app's Supabase project keeps the 1000-row default — so an
 * unbounded `.select()` over a wide dashboard range would be silently
 * truncated and every KPI, chart and table on the page would be wrong.
 *
 * `fetchAllRows` pages through `.range()` so dashboard ranges are always
 * complete, and it pages them CONCURRENTLY. That second part is what makes the
 * "All time" preset usable: the old sequential loop issued 13 requests one
 * after another, and since a deep-offset page costs 400-600 ms on this project
 * the tab sat on "Loading…" for ~16 s before rendering (and the KPI cards
 * showed a false `0` the whole time). Four pages in flight turns those 13
 * requests into 4 rounds.
 *
 * Notes on the design:
 *  * No count query. The row count is discovered by fetching speculatively in
 *    batches of `concurrency` and stopping at the first short page, which saves
 *    a round trip and needs no call-site changes; the cost is at most
 *    `concurrency - 1` requests that come back empty at the tail.
 *  * Pages are always stitched back in offset order. Deep-offset paging is only
 *    correct if the sort is total (callers end their `order` on a unique
 *    tiebreak), and re-ordering the batches by page index is what keeps a
 *    parallel run identical to a sequential one.
 *  * One retry per page. PostgREST answers 500 under concurrent deep offsets;
 *    the seed runs proved 4 is safe and 12 is not, so a single retry covers the
 *    tail without hiding a real failure.
 *
 * MAX_PAGES sizing: it must exceed ceil(rows / 1000) or the reader truncates
 * silently and every KPI above it is wrong. The dataset is ~13k attendance
 * rows (13 pages) and grows with the seed, so 60 keeps headroom.
 */

/**
 * Process-lifetime cache for the dashboard's shared dataset reads.
 *
 * The five dashboard tabs look like five separate features, but four of them
 * read the SAME underlying tables: Daily Check-ins, Member Growth, Member
 * Overview and Recent Activity all need the membership table, and three of them
 * also need the same attendance range and the member profiles. Each tab owns its
 * own query key, so switching tabs re-ran each tab's `queryFn` from scratch and
 * re-fetched those tables over the wire - even though the answer was already in
 * memory and could not have changed.
 *
 * This caches the PROMISE, not the resolved rows, and that distinction is the
 * whole point: a cache that only stored settled values would still fire a second
 * request whenever a caller arrived while the first was still in flight, which
 * is exactly what happens when you click through the tabs quickly. Caching the
 * promise makes concurrent callers await the SAME request.
 *
 * `staleAfter` bounds staleness for the app's lifetime. Nothing here is
 * user-authored data, and the tables only change when the demo seed is re-run,
 * so a generous window is safe; on expiry the entry is simply refetched on the
 * next read.
 */
const DEFAULT_TTL = 5 * 60_000

interface CacheEntry {
  promise: Promise<unknown>
  at: number
}

const entries = new Map<string, CacheEntry>()

/**
 * Memoises an async read by key.
 *
 * Failures are NOT cached: a rejected entry is evicted so the next reader
 * retries instead of inheriting a transient 500 forever. Evicting also stops an
 * unhandled rejection from being retained by the map.
 */
export function cachedDataset<T>(key: string, load: () => Promise<T>, staleAfter = DEFAULT_TTL): Promise<T> {
  const hit = entries.get(key)
  if (hit && Date.now() - hit.at < staleAfter) return hit.promise as Promise<T>

  const promise = load()
  entries.set(key, { promise: promise as Promise<unknown>, at: Date.now() })
  promise.catch(() => {
    // Only drop the entry if it is still the one we stored; a newer load may
    // have replaced it already.
    if (entries.get(key)?.promise === (promise as Promise<unknown>)) entries.delete(key)
  })
  return promise
}

/** Test/debug helper: drops every memoised dataset. */
export function clearDatasetCache(): void {
  entries.clear()
}

const PAGE_SIZE = 1000
// 60 pages = 60,000 rows. Raise alongside any dataset growth past that.
const MAX_PAGES = 60
// Pages in flight at once. 4 matches what the seed scripts proved safe against
// this PostgREST instance; raising it trades 500s for a marginally faster load.
const CONCURRENCY = 4
// One retry per page for the transient 500s that concurrent deep offsets cause.
const RETRIES = 1

/** Rows per PostgREST request. Exported so readers can build their own paging. */
export const PAGE = PAGE_SIZE

export type PageQuery<T> = { data: T[] | null; error: { message: string } | null }

export interface FetchAllOptions {
  /** Pages in flight at once. Defaults to 4. */
  concurrency?: number
  /** Retries per page after a failed request. Defaults to 1. */
  retries?: number
  /** Called after every completed batch with (rows so far, total if known). */
  onProgress?: (loaded: number, total: number | null) => void
}

async function fetchPage<T>(
  page: (from: number, to: number) => PromiseLike<PageQuery<T>>,
  from: number,
  retries: number,
): Promise<T[]> {
  let message = 'unknown error'
  for (let attempt = 0; attempt <= retries; attempt++) {
    const res = await page(from, from + PAGE_SIZE - 1)
    if (!res.error) return res.data ?? []
    message = res.error.message
  }
  throw new Error(message)
}

/**
 * One page, or `null` when it genuinely failed.
 *
 * Returning null instead of throwing is what lets `fetchAllRows` degrade to a
 * SEQUENTIAL retry of only the pages that failed, rather than losing an entire
 * batch - and with it the whole load - because one deep-offset request 500'd.
 */
async function tryFetchPage<T>(
  page: (from: number, to: number) => PromiseLike<PageQuery<T>>,
  from: number,
  retries: number,
): Promise<T[] | null> {
  try {
    return await fetchPage(page, from, retries)
  } catch {
    return null
  }
}

export async function fetchAllRows<T>(
  page: (from: number, to: number) => PromiseLike<PageQuery<T>>,
  opts: FetchAllOptions = {},
): Promise<T[]> {
  const concurrency = Math.max(1, opts.concurrency ?? CONCURRENCY)
  const retries = Math.max(0, opts.retries ?? RETRIES)

  const pages = new Map<number, T[]>()
  let loaded = 0
  let next = 0
  let exhausted = false

  while (!exhausted && next < MAX_PAGES) {
    const batch: number[] = []
    for (let i = 0; i < concurrency && next < MAX_PAGES; i++, next++) batch.push(next)
    const settled = await Promise.all(
      batch.map(async (i) => [i, await tryFetchPage(page, i * PAGE_SIZE, retries)] as const),
    )
    for (const [i, rows] of settled) {
      if (rows === null) continue // retried sequentially below
      pages.set(i, rows)
      loaded += rows.length
      // A short page is the end of the table. The final speculative page of a
      // run can also come back empty, which lands here too.
      if (rows.length < PAGE_SIZE) exhausted = true
    }
    opts.onProgress?.(loaded, null)
  }

  // Sequential retry for any page that failed inside a concurrent batch.
  //
  // This PostgREST instance answers 500 under concurrent DEEP OFFSETS - the
  // pages past ~4,000 rows consistently failed while offsets 0-3,000 succeeded,
  // which is why wide ranges were slow and sometimes came back short. Those
  // pages are now retried one at a time, which is the pattern that is reliable
  // at depth, and only the pages that actually failed pay the extra round trips.
  // Any page that still fails here is re-thrown rather than silently dropped:
  // a missing page would make every KPI above it quietly wrong.
  for (let i = 0; i < next; i++) {
    if (pages.has(i)) continue
    const rows = await fetchPage(page, i * PAGE_SIZE, retries)
    pages.set(i, rows)
    loaded += rows.length
    opts.onProgress?.(loaded, null)
  }

  const out: T[] = []
  for (let i = 0; i < pages.size; i++) out.push(...(pages.get(i) ?? []))
  return out
}
