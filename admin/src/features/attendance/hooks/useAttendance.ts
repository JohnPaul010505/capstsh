import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { fetchAllRows } from '@/features/dashboard/lib/fetchAll'

export function useAttendance(date?: string, category?: 'member' | 'trainer') {
  return useQuery({
    queryKey: ['attendance', date, category],
    queryFn: async () => {
      let query = supabase
        .from('attendance')
        .select('*, profiles!attendance_member_id_fkey(full_name, email, role, code)')
        .order('check_in_time', { ascending: false })

      if (date) query = query.eq('check_in_date', date)
      if (category === 'member') {
        const { data: memberIds } = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'member')
        const ids = (memberIds ?? []).map(r => r.id)
        query = ids.length > 0 ? query.in('member_id', ids) : query.in('member_id', [''])
      } else if (category === 'trainer') {
        const { data: roleIds } = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'trainer')
        const ids = (roleIds ?? []).map(r => r.id)
        query = ids.length > 0 ? query.in('member_id', ids) : query.in('member_id', [''])
      }

      // This was an unpaged `.select()`, so PostgREST returned only the first
      // 1,000 rows with no error — against 42k attendance rows the list simply
      // stopped there. Paging makes it complete; Phase 2's server-side paging
      // then replaces this so the page stops pulling the whole table.
      return fetchAllRows<any>(async (from, to) => {
        const res = await query
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
