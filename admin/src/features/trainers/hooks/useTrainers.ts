import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { normalizeProfileUpdates, syncAuthEmail } from '@/features/shared/profileUpdates'
import type { Profile } from '@/types'

export function useTrainers() {
  return useQuery({
    queryKey: ['trainers'],
    queryFn: async () => {
      const { data } = await supabase
        .from('profiles')
        .select('*')
        .eq('role', 'trainer')
        .order('code', { ascending: true })
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

/**
 * Persists editable trainer contact fields + specialty; refreshes the detail
 * and the trainers roster. Runs the same normaliser as the member hook: only
 * trimmed values go to Postgres (never ''), so a cleared field becomes `null`
 * instead of a 400 from a typed column.
 */
export function useUpdateTrainer() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, ...updates }: Partial<Profile> & { id: string }) => {
      const normalized = normalizeProfileUpdates(updates)
      // Same email-sync contract as useUpdateMember: auth.users must follow
      // profiles.email or sign-in breaks; skip when the email is unchanged so
      // plain contact edits don't depend on the API server.
      const newEmail = typeof normalized.email === 'string' ? normalized.email : null
      if (newEmail) {
        const { data: current } = await supabase
          .from('profiles')
          .select('email')
          .eq('id', id)
          .single()
        if ((current?.email ?? '').toLowerCase() !== newEmail.toLowerCase()) {
          await syncAuthEmail(id, newEmail)
        }
      }
      const { data, error } = await supabase
        .from('profiles')
        .update(normalized)
        .eq('id', id)
        .select()
        .single()
      if (error) throw error
      return data as Profile
    },
    onSuccess: (_data, vars) => {
      qc.invalidateQueries({ queryKey: ['trainer', vars.id] })
      qc.invalidateQueries({ queryKey: ['trainers'] })
    },
  })
}
