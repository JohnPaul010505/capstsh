import { useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { autoGrain, bucketize, daysBetween, prevWindow, type Grain, type Range } from '@/features/dashboard/lib/dateRange'
import { fetchAttendance, fetchMemberships } from '@/features/dashboard/lib/attendance'
import { planMatches, resolvePlan, type AttendanceRow, type PlanFilter } from '@/features/dashboard/lib/planFilter'

export interface CheckinPoint {
  key: string
  label: string
  full: string
  count: number
}

export interface CheckinRecord extends AttendanceRow {
  planName: string | null
}

export function useCheckinsTab(range: Range, plan: PlanFilter, grain?: Grain) {
  const effectiveGrain = useMemo(() => grain ?? autoGrain(range), [grain, range.start, range.end])

  const q = useQuery({
    queryKey: ['dash-checkins', range.start, range.end, plan],
    queryFn: async () => {
      const [rows, memberships] = await Promise.all([fetchAttendance(range), fetchMemberships()])
      const inPlan = rows.filter(r => {
        const planName = resolvePlan(memberships, r.member_id, r.check_in_date)
        return planMatches(plan, planName)
      })
      return { rows: inPlan, memberships }
    },
  })

  const derived = useMemo(() => {
    const rows = q.data?.rows ?? []
    const total = rows.length
    const memberCount = rows.filter(r => r.profiles?.role !== 'trainer').length
    const trainerCount = rows.filter(r => r.profiles?.role === 'trainer').length
    const days = Math.max(1, daysBetween(range.start, range.end))
    const avg = total / days

    const buckets = bucketize(range, effectiveGrain)
    const counts: Record<string, number> = {}
    rows.forEach(r => { counts[r.check_in_date] = (counts[r.check_in_date] || 0) + 1 })
    const points: CheckinPoint[] = buckets.map(b => {
      let n = 0
      // Bucket covers whole days, so sum the day totals inside [start, end].
      for (const day of Object.keys(counts)) {
        if (day >= b.start && day <= b.end) n += counts[day]
      }
      return { key: b.key, label: b.label, full: b.full, count: n }
    })

    const records: CheckinRecord[] = rows.map(r => ({
      ...r,
      planName: resolvePlan(q.data?.memberships, r.member_id, r.check_in_date),
    }))

    return { total, memberCount, trainerCount, avg, days, points, records, buckets }
  }, [q.data, range.start, range.end, effectiveGrain])

  // Previous-window total for the "% vs previous N days" line (only member
  // totals here — the Total Check-ins KPI intentionally shows no %).
  const prev = useQuery({
    queryKey: ['dash-checkins-prev', range.start, range.end, plan],
    queryFn: async () => {
      const w = prevWindow(range)
      const [rows, memberships] = await Promise.all([fetchAttendance(w), fetchMemberships()])
      return rows.filter(r => planMatches(plan, resolvePlan(memberships, r.member_id, r.check_in_date))).length
    },
  })

  const trend = useMemo(() => {
    if (prev.data === undefined) return undefined
    const days = Math.max(1, daysBetween(range.start, range.end))
    if (prev.data === 0) return derived.total > 0 ? { value: 100, label: `vs previous ${days} days` } : undefined
    return { value: Math.round(((derived.total - prev.data) / prev.data) * 100), label: `vs previous ${days} days` }
  }, [prev.data, derived.total, range.start, range.end])

  return { ...derived, trend, isLoading: q.isLoading || prev.isLoading, error: q.error ?? prev.error }
}
