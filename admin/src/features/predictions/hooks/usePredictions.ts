import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

export function usePredictions() {
  return useQuery({
    queryKey: ['predictions'],
    queryFn: async () => {
      const { data } = await supabase
        .from('predictions')
        // current_value/unit/data_points/span_days/date_from/date_to/daily_rate/
        // change/clamped come from migration 0030_prediction_basis.sql. Older rows
        // come back null and render as "recorded before provenance tracking".
        .select('*, profiles!predictions_member_id_fkey(full_name)')
        // Body-fat rows written before the feature was dropped are hidden: they
        // were computed from dev-seeded random values, not real measurements.
        .neq('metric_name', 'body_fat')
        .order('created_at', { ascending: false })
        .limit(50)
      return (data ?? []) as any[]
    },
  })
}

export interface GenerateResult {
  data: any
  source: 'ai' | 'fallback'
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
      const xSource = res.headers.get('x-forecast-source') || 'ai'
      const data = await res.json()
      // The AI service persists the forecasts itself (service role) — inserting
      // here as well would create duplicate rows.
      return { data, source: (xSource === 'fallback' ? 'fallback' : 'ai') as 'ai' | 'fallback' }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['predictions'] })
    },
  })
}

export interface MemberOption {
  id: string
  full_name: string
  email: string
  code: string | null
}

export function useMembersSimple() {
  return useQuery({
    queryKey: ['members-simple'],
    queryFn: async () => {
      const { data } = await supabase
        .from('profiles')
        .select('id, full_name, email, code')
        .eq('role', 'member')
        .order('full_name')
      return (data ?? []) as MemberOption[]
    },
  })
}
