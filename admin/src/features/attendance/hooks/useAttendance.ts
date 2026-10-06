import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { fetchAllRows } from '@/features/dashboard/lib/fetchAll'
import type { Range } from '@/features/dashboard/lib/dateRange'

// The two SELECT shapes this hook needs, so the role-filtered branch below and
// the unfiltered one cannot drift apart.
const BASE_SELECT = '*, profiles!attendance_member_id_fkey(full_name, email, role, code)'
const INNER_SELECT = '*, profiles!attendance_member_id_fkey!inner(full_name, email, role, code)'

/**
 * Check-ins inside a day RANGE, for one role (or both).
 *
 * This was `useAttendance(date)` with a single `.eq('check_in_date', date)`. It
 * is now a window, so the admin can read a whole month at once - which is how a
 * gym actually reads its sheet - without that costing a different code path.
 *
 * `check_in_date` is a `date` column, so the bounds stay plain 'YYYY-MM-DD'
 * strings. That is NOT the case for the `created_at` columns the other list
 * pages filter on, which are `timestamptz` and need `localStartIso`/
 * `localEndIso`; see `usePredictions`.
 */
export function useAttendance(range?: Range, category?: 'member' | 'trainer') {
  return useQuery({
    queryKey: ['attendance', range?.start, range?.end, category],
    queryFn: async () => {
      // Role is a property of the JOINED profile, not of the attendance row, so
      // it cannot be a filter on this query. Resolving the ids and passing them
      // to `in()` used to send ~987 UUIDs in the query string - a ~40KB URL,
      // which PostgREST rejects with 400 and the page then sits on "Loading..."
      // forever.
      //
      // Filtering the JOIN is the correct shape and sends no ids at all. If the
      // database later refuses an inner-join filter on an embedded resource,
      // the fallback is a `!inner` join plus a local filter, never the id list.
      //
      // THIS MUST RETURN A FRESH BUILDER PER PAGE.
      //
      // A PostgrestFilterBuilder is MUTABLE and single-use: `.order()` appends
      // another `order=` param to the shared URL and `.range()` overwrites its
      // `offset`. This hook used to build the query once, outside the callback,
      // and hand that ONE object to `fetchAllRows`, which calls the callback
      // CONCURRENTLY (4 pages in flight). All four `.order()`/`.range()` pairs
      // therefore ran against the same object before any fetch read its URL, so
      // every request went out at the LAST page's offset with `order=` repeated
      // four times:
      //
      //   ...&order=check_in_time.desc,id.desc x4&offset=3000&limit=1000
      //
      // Page 0's `offset=0` was never requested. The page is scoped to a day or
      // two, so `offset=3000` matched nothing and answered 200 with zero rows -
      // and the page then rendered "No attendance records" for EVERY date, with
      // no error anywhere, while the dashboard (whose `pageOf` builds a new
      // builder per page) showed the same rows fine. Building inside the
      // callback is the same discipline `fetchAttendance` already uses.
      const pageOf = async (from: number, to: number) => {
        let q = supabase.from('attendance').select(category ? INNER_SELECT : BASE_SELECT)
        if (category) q = q.eq('profiles.role', category)
        if (range) {
          q = q.gte('check_in_date', range.start)
          q = q.lte('check_in_date', range.end)
        }

        // `check_in_time` then `id`: the unique tiebreak keeps pages disjoint
        // when several check-ins share a timestamp, which PostgREST's OFFSET
        // paging needs.
        const res = await q
          .order('check_in_time', { ascending: false })
          .order('id', { ascending: false })
          .range(from, to)
        return {
          data: (res.data ?? []) as any[],
          error: res.error ? { message: res.error.message } : null,
        }
      }

      // This pages the whole window, so the count is whatever the selected days
      // hold. `All time` is the one to watch: that is the entire attendance
      // table (~13k rows) paged in at 1,000 a request and then filtered in the
      // browser by `RecordsTable`. It is the slowest chip on this page by an
      // order of magnitude - the dashboard's Member Overview tab already pages a
      // larger table, so it is inside what this app does, but it is not free.
      return fetchAllRows<any>(pageOf)
    },
  })
}
