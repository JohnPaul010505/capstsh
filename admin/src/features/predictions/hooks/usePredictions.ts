import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

export function usePredictions() {
  return useQuery({
    queryKey: ['predictions'],
    queryFn: async () => {
      const { data } = await supabase
        .from('predictions')
        .select('*, profiles!predictions_member_id_fkey(full_name)')
        .order('created_at', { ascending: false })
        .limit(50)
      return (data ?? []) as any[]
    },
  })
}

export function useGeneratePredictions() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ memberId, daysAhead = 30 }: { memberId: string; daysAhead?: number }) => {
      const res = await fetch('/api/ai/predictions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ member_id: memberId, days_ahead: daysAhead }),
      })
      if (!res.ok) {
        const err = await res.json().catch(() => ({}))
        throw new Error(err.detail || err.error || 'Failed to generate predictions')
      }
      const data = await res.json()
      // The AI service persists the forecasts itself (service role) — inserting
      // here as well would create duplicate rows.
      return data
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['predictions'] })
    },
  })
}

export function useMembersSimple() {
  return useQuery({
    queryKey: ['members-simple'],
    queryFn: async () => {
      const { data } = await supabase
        .from('profiles')
        .select('id, full_name')
        .eq('role', 'member')
        .order('full_name')
      return data ?? []
    },
  })
}
