import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { normalizeProfileUpdates } from '@/features/shared/profileUpdates'
import type { Profile } from '@/types'

export function useMembers(search?: string) {
  return useQuery({
    queryKey: ['members', search],
    queryFn: async () => {
      let query = supabase
        .from('profiles')
        .select('*')
        .eq('role', 'member')
        .order('code', { ascending: true })

      if (search) {
        query = query.ilike('full_name', `%${search}%`)
      }

      const { data } = await query
      return (data ?? []) as Profile[]
    },
  })
}

export function useMember(id: string) {
  return useQuery({
    queryKey: ['member', id],
    queryFn: async () => {
      const { data } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', id)
        .single()
      return data as Profile | null
    },
  })
}

export function useCreateMember() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (member: { full_name: string; email: string; phone?: string }) => {
      const { data, error } = await supabase
        .from('profiles')
        .insert({ ...member, role: 'member' })
        .select()
        .single()
      if (error) throw error
      return data as Profile
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['members'] })
    },
  })
}

/**
 * Persists an admin edit to a member's `profiles` row.
 *
 * Two things this used to get wrong, both fixed here rather than in the page:
 *
 *  1. `date_of_birth: ''` — a `date` column rejects the empty string with
 *     `22007 invalid input syntax for type date`, and Postgres rolls the whole
 *     statement back, so an admin who only meant to fix a phone number lost the
 *     edit with no message. Empty now becomes `null`.
 *  2. Only `['members']` was invalidated, so the open detail page kept showing
 *     the pre-edit row until a reload.
 */
export function useUpdateMember() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, ...updates }: Partial<Profile> & { id: string }) => {
      const { data, error } = await supabase
        .from('profiles')
        .update(normalizeProfileUpdates(updates))
        .eq('id', id)
        .select()
        .single()
      if (error) throw error
      return data as Profile
    },
    onSuccess: (_data, vars) => {
      qc.invalidateQueries({ queryKey: ['members'] })
      qc.invalidateQueries({ queryKey: ['member', vars.id] })
    },
  })
}
