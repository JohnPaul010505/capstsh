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

/** Pending renewal requests (status = pending), with member profile join. */
export function useRenewalRequests() {
  return useQuery({
    queryKey: ['membership_renewal_requests', 'pending'],
    queryFn: async () => {
      // requested/approved price columns come with migration 0041; before it
      // is applied the expanded select 400s, so fall back to the old shape and
      // let the page treat "amount columns missing" as amount-not-tracked.
      const expanded = await supabase
        .from('membership_renewal_requests')
        .select('*, profiles!membership_renewal_requests_member_id_fkey(full_name, code, email)')
        .eq('status', 'pending')
        .order('requested_at', { ascending: false })
      if (!expanded.error) {
        // `*` already carries requested_price/approved_price/start_date/end_date
        // when the migration exists; normalise legacy rows that lack them.
        return (expanded.data ?? []).map(normalizeRenewalRequest) as import('@/types').MembershipRenewalRequest[]
      }
      const legacy = await supabase
        .from('membership_renewal_requests')
        .select('*, profiles!membership_renewal_requests_member_id_fkey(full_name, code, email)')
        .eq('status', 'pending')
        .order('requested_at', { ascending: false })
      if (legacy.error) throw legacy.error
      return (legacy.data ?? []).map(normalizeRenewalRequest) as import('@/types').MembershipRenewalRequest[]
    },
  })
}

/**
 * Rows written before migration 0041 have no price/date columns on the wire;
 * give them explicit nulls so every consumer can rely on the fields.
 */
function normalizeRenewalRequest(row: Record<string, unknown>) {
  return {
    ...row,
    start_date: row.start_date ?? null,
    end_date: row.end_date ?? null,
    requested_price: row.requested_price == null ? null : Number(row.requested_price),
    approved_price: row.approved_price == null ? null : Number(row.approved_price),
  }
}

