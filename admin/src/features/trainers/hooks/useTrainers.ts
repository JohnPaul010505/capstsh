import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { Profile } from '@/types'

export function useTrainers() {
  return useQuery({
    queryKey: ['trainers'],
    queryFn: async () => {
      const { data } = await supabase
        .from('profiles')
        .select('*')
        .eq('role', 'trainer')
        .order('created_at', { ascending: false })
      return (data ?? []) as Profile[]
    },
  })
}

export function useTrainer(id: string) {
  return useQuery({
    queryKey: ['trainer', id],
    queryFn: async () => {
      const { data: profile } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', id)
        .single()

      const { data: assignments } = await supabase
        .from('trainer_assignments')
        .select('*, profiles!trainer_assignments_member_id_fkey(*)')
        .eq('trainer_id', id)
        .eq('status', 'active')

      return { profile: profile as Profile | null, members: (assignments ?? []) as any[] }
    },
  })
}
