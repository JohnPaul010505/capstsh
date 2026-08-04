import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

export function useMemberships(planName?: string) {
  return useQuery({
    queryKey: ['memberships', planName],
    queryFn: async () => {
      let query = supabase
        .from('memberships')
        .select('*, profiles!memberships_member_id_fkey(full_name, email, code)')
        .order('created_at', { ascending: false })

      if (planName) {
        query = query.eq('plan_name', planName)
      }

      const { data } = await query
      return data ?? []
    },
  })
}

export function useAttendanceLast7Days() {
  return useQuery({
    queryKey: ['attendance-7days'],
    queryFn: async () => {
      const sevenDaysAgo = new Date()
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7)
      const { data } = await supabase
        .from('attendance')
        .select('member_id, check_in_time, check_in_date')
        .gte('check_in_time', sevenDaysAgo.toISOString())
      return data ?? []
    },
  })
}

export function useCreateMembership() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (membership: {
      member_id: string
      plan_name: string
      price: number
      start_date: string
      end_date: string
    }) => {
      const { data, error } = await supabase
        .from('memberships')
        .insert({
          ...membership,
          status: 'active',
        })
        .select()
        .single()
      if (error) throw error
      return data
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['memberships'] })
    },
  })
}

export function useUpdateMembership() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, ...updates }: Record<string, unknown> & { id: string }) => {
      const { data, error } = await supabase
        .from('memberships')
        .update(updates)
        .eq('id', id)
        .select()
        .single()
      if (error) throw error
      return data
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['memberships'] })
    },
  })
}

export function useDeleteMembership() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from('memberships').delete().eq('id', id)
      if (error) throw error
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['memberships'] })
    },
  })
}
