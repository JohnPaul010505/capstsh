import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

export function useWorkouts() {
  return useQuery({
    queryKey: ['workouts'],
    queryFn: async () => {
      const { data } = await supabase
        .from('workout_logs')
        .select('*, profiles!workout_logs_member_id_fkey(full_name)')
        .order('logged_at', { ascending: false })
      return data ?? []
    },
  })
}

export function useMemberWorkouts(memberId: string) {
  return useQuery({
    queryKey: ['member-workouts', memberId],
    queryFn: async () => {
      const { data } = await supabase
        .from('workout_logs')
        .select('*')
        .eq('member_id', memberId)
        .order('logged_at', { ascending: false })
        .limit(10)
      return data ?? []
    },
  })
}
