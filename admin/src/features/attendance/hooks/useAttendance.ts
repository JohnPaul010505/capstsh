import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { fetchAllRows } from '@/features/dashboard/lib/fetchAll'

export function useAttendance(date?: string, category?: 'member' | 'trainer') {
  return useQuery({
    queryKey: ['attendance', date, category],
    queryFn: async () => {
      const query = supabase
        .from('attendance')
        .select('*, profiles!attendance_member_id_fkey(full_name, email, role, code)')

      // Role is a property of the JOINED profile, not of the attendance row, so
      // it cannot be a filter on this query. Resolving the ids and passing them
      // to `in()` used to send ~987 UUIDs in the query string - a ~40KB URL,
      // which PostgREST rejects with 400 and the page then sits on "Loading..."
      // forever.
      //
      // Filtering the JOIN is the correct shape and sends no ids at all. If the
      // database later refuses an inner-join filter on an embedded resource,
      // the fallback is a `!inner` join plus a local filter, never the id list.
      let q = query
      if (category) {
        q = query.select('*, profiles!attendance_member_id_fkey!inner(full_name, email, role, code)')
          .eq('profiles.role', category)
      }
      if (date) q = q.eq('check_in_date', date)

      // This was an unpaged `.select()`, so PostgREST returned only the first
      // 1,000 rows with no error — against 42k attendance rows the list simply
      // stopped there. Paging makes it complete.
      return fetchAllRows<any>(async (from, to) => {
        const res = await q
          // `check_in_time` then `id`: the unique tiebreak keeps pages disjoint
          // when several check-ins share a timestamp. Declared ONCE - the earlier
          // version also ordered by check_in_time in the builder above, which
          // sent `order=check_in_time.desc,check_in_time.desc,id.desc`.
          .order('check_in_time', { ascending: false })
          .order('id', { ascending: false })
          .range(from, to)
        return {
          data: (res.data ?? []) as any[],
          error: res.error ? { message: res.error.message } : null,
        }
      })
    },
  })
}
