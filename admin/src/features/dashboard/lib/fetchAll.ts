/**
 * PostgREST returns at most 1000 rows per request unless `.limit()` says
 * otherwise, and the app's Supabase project keeps the 1000-row default —
 * so an unbounded `.select()` over a wide dashboard range (e.g. the 3,400+
 * row "All time" attendance set) would be silently truncated and every KPI,
 * chart and table on the page would be wrong.
 *
 * `fetchAllRows` pages through `.range()` so dashboard ranges are always
 * complete. Callers pass a page factory; the loop stops on the first short
 * page and is capped at MAX_PAGES (10k rows) as a backstop.
 */

const PAGE_SIZE = 1000
const MAX_PAGES = 10

type PageQuery<T> = { data: T[] | null; error: { message: string } | null }

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
