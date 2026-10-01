import { useMemo } from 'react'
import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { autoGrain, bucketize, daysBetween, type Grain, type Range } from '@/features/dashboard/lib/dateRange'
import { fetchMembershipsInRange } from '@/features/dashboard/lib/attendance'
import type { PlanFilter } from '@/features/dashboard/lib/planFilter'

export interface RevenuePoint {
  key: string
  label: string
  full: string
  value: number
}

export interface RevenueRecord {
  id: string
  startDate: string
  createdAt: string
  planName: string
  price: number
  status: string
  memberName: string
  memberCode: string | null
}

/**
 * Revenue Overview tab.
 *
 * Revenue date = membership `start_date` (see fetchMembershipsInRange): the
 * data has no payments table and `created_at` is backdated outside the test
 * range, so start_date is the only column that behaves like a sale date when
 * the admin picks Jan 15 → Mar 15.
 */
export function useRevenueTab(range: Range, plan: PlanFilter, grain?: Grain) {
  const effectiveGrain = useMemo(() => grain ?? autoGrain(range), [grain, range.start, range.end])

  const q = useQuery({
    queryKey: ['dash-revenue', range.start, range.end, plan],
    // Keep the previous range on screen while the next one loads. Every KPI here
    // comes from a whole-table fetch, so without this a range change
    // blanks the tab and the cards briefly show zeros for the NEW range.
    placeholderData: keepPreviousData,
    queryFn: async () => {
      const rows = await fetchMembershipsInRange(range)
      return plan === 'all' ? rows : rows.filter(r => r.plan_name === plan)
    },
  })

  const derived = useMemo(() => {
    const rows = q.data ?? []
    const days = Math.max(1, daysBetween(range.start, range.end))

    const total = rows.reduce((s, r) => s + (Number(r.price) || 0), 0)
    const transactions = rows.length
    const avg = total / days

    const byDay: Record<string, number> = {}
    rows.forEach(r => {
      byDay[r.start_date] = (byDay[r.start_date] || 0) + (Number(r.price) || 0)
    })
    let peakDay = ''
    let peakAmount = 0
    Object.keys(byDay).forEach(d => {
      if (byDay[d] > peakAmount || (byDay[d] === peakAmount && d > peakDay)) {
        peakAmount = byDay[d]
        peakDay = d
      }
    })

    const buckets = bucketize(range, effectiveGrain)
    const points: RevenuePoint[] = buckets.map(b => {
      let v = 0
      for (const day of Object.keys(byDay)) if (day >= b.start && day <= b.end) v += byDay[day]
      return { key: b.key, label: b.label, full: b.full, value: v }
    })

    const records: RevenueRecord[] = rows.map(r => ({
      id: r.id,
      startDate: r.start_date,
      createdAt: r.created_at,
      planName: r.plan_name,
      price: Number(r.price) || 0,
      status: r.status,
      memberName: r.profiles?.full_name ?? 'Unknown',
      memberCode: r.profiles?.code ?? null,
    }))

    return { total, avg, days, transactions, peakDay, peakAmount, points, records }
  }, [q.data, range.start, range.end, effectiveGrain])

  return { ...derived, isLoading: q.isLoading, error: q.error }
}
