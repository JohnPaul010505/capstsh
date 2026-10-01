import { useMemo } from 'react'
import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { autoGrain, bucketize, daysBetween, type Grain, type Range } from '@/features/dashboard/lib/dateRange'
import { fetchAttendance, fetchMemberships } from '@/features/dashboard/lib/attendance'
import { planIndexFor, planMatches, resolvePlanIndexed, type AttendanceRow, type PlanFilter } from '@/features/dashboard/lib/planFilter'

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
    // Keep the previous range on screen while the next one loads. Every KPI here
    // comes from a whole-table fetch, so without this a range change
    // blanks the tab and the cards briefly show zeros for the NEW range.
    placeholderData: keepPreviousData,
    queryFn: async () => {
      const [rows, memberships] = await Promise.all([fetchAttendance(range), fetchMemberships()])
      // Indexed plan lookup: this filter runs once per attendance row, and the
      // unindexed version re-scanned all 1,860 memberships for each of them.
      const planIndex = planIndexFor(memberships)
      const inPlan = rows.filter(r => {
        const planName = resolvePlanIndexed(planIndex, r.member_id, r.check_in_date)
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
      for (const day of Object.keys(counts)) if (day >= b.start && day <= b.end) n += counts[day]
      return { key: b.key, label: b.label, full: b.full, count: n }
    })

    // Same index the filter above used — built once, memoised by array identity.
    const planIndex = planIndexFor(q.data?.memberships)
    const records: CheckinRecord[] = rows.map(r => ({
      ...r,
      planName: resolvePlanIndexed(planIndex, r.member_id, r.check_in_date),
    }))

    return { total, memberCount, trainerCount, avg, days, points, records, buckets }
  }, [q.data, range.start, range.end, effectiveGrain])

  return { ...derived, isLoading: q.isLoading, error: q.error }
}
