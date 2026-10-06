import { useEffect, useRef } from 'react'
import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

/**
 * Server-side paging + search + date filtering for the admin list pages.
 *
 * Why server-side and not client-side: with 1,077 profiles and 42k attendance
 * rows, a page cannot hold the whole table, and PostgREST silently truncates an
 * unpaged select at 1,000 rows. Filtering in the browser would also be wrong —
 * a search for "M034" has to reach the row, not the first 1,000 of them.
 *
 * Every query here returns the total alongside the page (`count: 'exact'`), so
 * the pagination footer can render "page 3 of 66" without a second round trip.
 */

export interface SortSpec {
  column: string
  ascending?: boolean
}

export interface PagedTableOptions {
  table: string
  select: string
  /**
   * MUST end with a unique column (usually `id`). PostgREST pages by OFFSET, so
   * without a unique tiebreak two rows sharing a sort value can straddle a page
   * boundary — one row appears twice and another is never seen.
   */
  orderBy: SortSpec[]
  /** 1-based. */
  page: number
  pageSize: number
  /** Matched case-insensitively as a substring against `searchColumns`. */
  search?: string
  searchColumns?: string[]
  /** Column the date range filters, e.g. 'start_date' or 'created_at'. */
  dateColumn?: string
  /** Inclusive 'YYYY-MM-DD' bounds. */
  from?: string
  to?: string
  /**
   * Equality predicates applied in the query, e.g. `{ plan_name: 'Monthly' }`.
   *
   * These must be in the query and not applied to the returned page: a filter
   * applied after paging shrinks the rows shown but not `total`, so the footer
   * would claim 1,800 records while page 1 shows 20 of them.
   */
  eq?: Record<string, string | undefined>
  /**
   * `in` predicates, e.g. `{ member_id: [...] }`. Used where the value comes
   * from a lookup rather than the UI — a membership list filtered by the
   * members matching a search term. An empty array means "match nothing", so
   * the caller gets an empty page rather than the unfiltered list.
   */
  inFilter?: Record<string, string[] | undefined>
  enabled?: boolean
}

export interface PagedTableResult<T> {
  rows: T[]
  total: number
  pageCount: number
}

/**
 * PostgREST's `or=` filter is a mini-language: commas separate conditions and
 * `*` is the wildcard, so a comma, a bracket or a `*` typed into the search box
 * would otherwise change the filter's shape — or produce a 400 for the whole
 * query. Strip them rather than interpolating raw input into the filter string.
 */
export function sanitizeSearchTerm(term: string): string {
  return term.replace(/[,()*\\%]/g, ' ').replace(/\s+/g, ' ').trim()
}

/**
 * Applies the search term as a PostgREST `or=` filter.
 *
 * Generic over the builder rather than naming a concrete PostgREST type: the
 * builder's row-type parameter is inferred from the (dynamic) select string, so
 * any fixed type annotation produces an incompatible-generics error the moment
 * `.or()` is chained onto it.
 */
export function applySearch<T extends { or: (filter: string) => T }>(
  query: T,
  search: string | undefined,
  columns: string[] | undefined,
): T {
  const term = sanitizeSearchTerm(search ?? '')
  if (!term || !columns?.length) return query
  // `*` is the wildcard inside an or() filter (unlike `%` in a top-level ilike).
  return query.or(columns.map((c) => `${c}.ilike.*${term}*`).join(','))
}

export function usePagedTable<T = any>(opts: PagedTableOptions): PagedTableResult<T> & {
  isLoading: boolean
  isError: boolean
} {
  const {
    table, select, orderBy, page, pageSize,
    search, searchColumns, dateColumn, from, to, eq, inFilter, enabled = true,
  } = opts

  const query = useQuery({
    queryKey: [table, 'paged', { page, pageSize, search, from, to, eq, inFilter, orderBy }],
    enabled,
    // Keep the previous page on screen while the next one loads: the pager, the
    // tab badges and the stat cards all read total from this query and would
    // otherwise drop to 0 on every turn - and PaginationFooter already promises
    // the reader that the previous page stays put during the fetch.
    placeholderData: keepPreviousData,
    queryFn: async (): Promise<PagedTableResult<T>> => {
      let q = supabase.from(table).select(select, { count: 'exact' })
      for (const [col, val] of Object.entries(eq ?? {})) {
        if (val !== undefined) q = q.eq(col, val)
      }
      for (const [col, vals] of Object.entries(inFilter ?? {})) {
        if (vals === undefined) continue
        // An empty list must match nothing, not everything.
        q = vals.length ? q.in(col, vals) : q.in(col, ['00000000-0000-0000-0000-000000000000'])
      }
      q = applySearch(q, search, searchColumns)
      if (dateColumn) {
        if (from) q = q.gte(dateColumn, from)
        if (to) q = q.lte(dateColumn, to)
      }
      for (const o of orderBy) q = q.order(o.column, { ascending: o.ascending ?? true })
      // Clamp the page so a filter that shrinks the result set cannot request a
      // range past the end and render an empty table.
      const offset = Math.max(0, (page - 1) * pageSize)
      q = q.range(offset, offset + pageSize - 1)

      const { data, count, error } = await q
      if (error) throw new Error(error.message)
      const total = count ?? 0
      return {
        rows: (data ?? []) as T[],
        total,
        pageCount: Math.max(1, Math.ceil(total / pageSize)),
      }
    },
  })

  return {
    rows: (query.data?.rows ?? []) as T[],
    total: query.data?.total ?? 0,
    pageCount: query.data?.pageCount ?? 1,
    isLoading: query.isLoading,
    isError: query.isError,
  }
}

/**
 * Reset the page number to 1 whenever an input that changes the result set
 * changes. Searching from page 5 of an unfiltered list otherwise lands on an
 * out-of-range page and the table renders empty.
 *
 * Takes the deps as a rest argument so the call site reads as a plain list of
 * watched values: `useResetPageOnChange(setPage, [search, from, to])`.
 */
export function useResetPageOnChange(setPage: (n: number) => void, ...deps: unknown[]) {
  const first = useRef(true)
  useEffect(() => {
    if (first.current) {
      first.current = false
      return
    }
    setPage(1)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps)
}
