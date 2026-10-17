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

/**
 * useConfirmEnrollment is intentionally NOT exported here.
 *
 * Confirming an enrollment requires creating a Supabase auth user + profile,
 * which can only be done with the service-role key. That happens server-side
 * in POST /api/confirm-enrollment (admin/server/index.js), called from
 * QRPage.handleConfirm. The browser's anon-key client cannot create auth users,
 * so a client-side confirm hook cannot work correctly and is omitted.
 */

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
