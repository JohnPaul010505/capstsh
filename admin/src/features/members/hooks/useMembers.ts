import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { Profile } from '@/types'

export function useMembers(search?: string) {
  return useQuery({
    queryKey: ['members', search],
    queryFn: async () => {
      let query = supabase
        .from('profiles')
        .select('*')
        .eq('role', 'member')
        .order('created_at', { ascending: false })

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

export function useUpdateMember() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, ...updates }: Partial<Profile> & { id: string }) => {
      const { data, error } = await supabase
        .from('profiles')
        .update(updates)
        .eq('id', id)
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
