/**
 * PostgREST returns at most 1000 rows per request unless `.limit()` says
 * otherwise, and the app's Supabase project keeps the 1000-row default —
 * so an unbounded `.select()` over a wide dashboard range (e.g. the 3,400+
 * row "All time" attendance set) would be silently truncated and every KPI,
 * chart and table on the page would be wrong.
 *
 * `fetchAllRows` pages through `.range()` so dashboard ranges are always
 * complete. Callers pass a page factory; the loop stops on the first short
 * page and MAX_PAGES is only a runaway backstop.
 *
 * MAX_PAGES sizing: it must exceed ceil(rows / 1000) or the reader truncates
 * silently and every KPI above it is wrong. The plan originally called for 40
 * (40,000 rows) against the pre-overlay dataset, but the regular-attender
 * overlay in lib/attendance.mjs took attendance to 42,141 rows — which needs
 * 43 pages. 60 keeps headroom for the next data addition. Raising this is not
 * free: the dashboard fetches the full history on every range change, so a
 * bigger cap means a slower first paint. Phase 2's server-side paging is what
 * actually fixes that; this cap only stops the data being wrong.
 */

const PAGE_SIZE = 1000
// 60 pages = 60,000 rows. Raise alongside any dataset growth past that.
const MAX_PAGES = 60

export type PageQuery<T> = { data: T[] | null; error: { message: string } | null }

export async function fetchAllRows<T>(page: (from: number, to: number) => PromiseLike<PageQuery<T>>): Promise<T[]> {
  const out: T[] = []
  for (let i = 0; i < MAX_PAGES; i++) {
    const from = i * PAGE_SIZE
    const res = await page(from, from + PAGE_SIZE - 1)
    if (res.error) throw new Error(res.error.message)
    const rows = res.data ?? []
    out.push(...rows)
    if (rows.length < PAGE_SIZE) break
  }
  return out
}
