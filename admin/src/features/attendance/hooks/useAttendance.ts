import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

export function useAttendance(date?: string, category?: 'daily' | 'monthly' | 'trainer') {
  return useQuery({
    queryKey: ['attendance', date, category],
    queryFn: async () => {
      let query = supabase
        .from('attendance')
        .select('*, profiles!attendance_member_id_fkey(full_name, email, role, code)')
        .order('check_in_time', { ascending: false })

      if (date) query = query.eq('check_in_date', date)
      if (category && category !== 'trainer') {
        const { data: planIds } = await supabase
          .from('memberships')
          .select('member_id')
          .eq('plan_name', category === 'daily' ? 'Daily' : 'Monthly')
        const ids = (planIds ?? []).map(r => r.member_id)
        query = ids.length > 0 ? query.in('member_id', ids) : query.in('member_id', [''])
      } else if (category === 'trainer') {
        const { data: roleIds } = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'trainer')
        const ids = (roleIds ?? []).map(r => r.id)
        query = ids.length > 0 ? query.in('member_id', ids) : query.in('member_id', [''])
      }

      const { data } = await query
      return data ?? []
    },
  })
}
