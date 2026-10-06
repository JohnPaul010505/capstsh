import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { fetchAllRows } from '@/features/dashboard/lib/fetchAll'
import { isAllTime, localEndIso, localStartIso, type Range } from '@/features/dashboard/lib/dateRange'

/**
 * The newest stored forecasts, optionally narrowed to the page's date window.
 *
 * `created_at` is a `timestamptz`, so the bounds are LOCAL-midnight ISO instants
 * (`localStartIso` / `localEndIso`) rather than bare 'YYYY-MM-DD' strings. The
 * bare strings get cast by Postgres in the session timezone - UTC here - which
 * puts every bound 8 hours before local midnight in PH and quietly drops the
 * first and last day of the window the admin asked for.
 *
 * On `All time` NO filter is sent at all, which is both the cheaper query and
 * the one that keeps this page's landing render identical to the one before the
 * picker existed (see `isAllTime` for the member who would otherwise vanish).
 */
export function usePredictions(range?: Range) {
  const all = !range || isAllTime(range)
  const from = all ? undefined : localStartIso(range.start)
  const to = all ? undefined : localEndIso(range.end)

  return useQuery({
    queryKey: ['predictions', from, to],
    queryFn: async () => {
      let q = supabase
        .from('predictions')
        // current_value/unit/data_points/span_days/date_from/date_to/daily_rate/
        // change/clamped come from migration 0030_prediction_basis.sql. Older rows
        // come back null and render as "recorded before provenance tracking".
        .select('*, profiles!predictions_member_id_fkey(full_name)')
        // Body-fat rows written before the feature was dropped are hidden: they
        // were computed from dev-seeded random values, not real measurements.
        .neq('metric_name', 'body_fat')
      if (from) q = q.gte('created_at', from)
      if (to) q = q.lte('created_at', to)
      const { data } = await q
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
      // Paged: this drives MemberSelect's option list. 987 members sits just
      // under PostgREST's 1,000-row default, so the unpaged version worked by
      // one member of luck and would have silently started dropping options as
      // soon as the roster grew.
      return fetchAllRows<MemberOption>(async (from, to) => {
        const res = await supabase
          .from('profiles')
          .select('id, full_name, email, code')
          .eq('role', 'member')
          .order('full_name', { ascending: true })
          .order('id', { ascending: true })
          .range(from, to)
        return {
          data: (res.data ?? []) as MemberOption[],
          error: res.error ? { message: res.error.message } : null,
        }
      })
    },
  })
}
