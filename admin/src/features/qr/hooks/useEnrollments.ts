import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { Enrollment } from '@/types'

export function useEnrollments() {
  return useQuery({
    queryKey: ['enrollments'],
    queryFn: async () => {
      const { data } = await supabase
        .from('enrollments')
        .select('*')
        .order('created_at', { ascending: false })
      return (data ?? []) as Enrollment[]
    },
  })
}

export function useCreateEnrollment() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (enrollment: {
      full_name: string
      email: string
      phone?: string
      date_of_birth?: string
      gender?: string
      address?: string
    }) => {
      const { data, error } = await supabase
        .from('enrollments')
        .insert({
          ...enrollment,
          phone: enrollment.phone || null,
          date_of_birth: enrollment.date_of_birth || null,
          gender: enrollment.gender || null,
          address: enrollment.address || null,
          status: 'pending',
        })
        .select()
        .single()
      if (error) throw error
      return data as Enrollment
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['enrollments'] })
    },
  })
}

export function useConfirmEnrollment() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (enrollment: Enrollment) => {
      const confirmedAt = new Date().toISOString()
      const { data: { user } } = await supabase.auth.getUser()
      const confirmedBy = user?.id

      const { error: updateError } = await supabase
        .from('enrollments')
        .update({ status: 'confirmed', confirmed_at: confirmedAt, confirmed_by: confirmedBy })
        .eq('id', enrollment.id)
      if (updateError) throw updateError

      const profileData = {
        id: enrollment.id,
        role: 'member',
        full_name: enrollment.full_name,
        email: enrollment.email,
        phone: enrollment.phone || null,
        date_of_birth: enrollment.date_of_birth || null,
        gender: enrollment.gender || null,
      }
      const { error: profileError } = await supabase.from('profiles').insert(profileData)
      if (profileError) throw profileError
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['enrollments'] })
      qc.invalidateQueries({ queryKey: ['members'] })
    },
  })
}

export function useRejectEnrollment() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase
        .from('enrollments')
        .update({ status: 'rejected' })
        .eq('id', id)
      if (error) throw error
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['enrollments'] })
    },
  })
}

export function useUpdateEnrollment() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, ...updates }: Partial<Enrollment> & { id: string }) => {
      const { data, error } = await supabase
        .from('enrollments')
        .update(updates)
        .eq('id', id)
        .select()
        .single()
      if (error) throw error
      return data as Enrollment
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['enrollments'] })
    },
  })
}
