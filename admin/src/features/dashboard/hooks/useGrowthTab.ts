import { useMemo } from 'react'
import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { autoGrain, bucketize, daysBetween, toDay, type Grain, type Range } from '@/features/dashboard/lib/dateRange'
import { fetchAttendance, fetchMemberProfiles, fetchMemberships } from '@/features/dashboard/lib/attendance'
import {
  memberPlanMatchesIndexed, planIndexFor, planMatches, resolvePlanIndexed, type PlanFilter,
} from '@/features/dashboard/lib/planFilter'

export interface GrowthPoint {
  key: string
  label: string
  full: string
  value: number
}

export interface GrowthRecord {
  id: string
  day: string
  createdAt: string
  memberName: string
  memberCode: string | null
  planName: string
  status: string
}

/**
 * Member Growth tab: members whose profile was created inside the range,
 * plotted as daily additions per bucket.
 *
 * Two averages come out of this, and conflating them is what made the All-time
 * chart look broken:
 *   `avg`          - new members per DAY, which is what the "Daily Average" KPI
 *                    card states and nothing else may reuse.
 *   `avgPerBucket` - new members per CHART BUCKET. The benchmark line on the
 *                    trend is drawn against a bucket axis, so at All time it
 *                    has to read ~21.9 (45 monthly buckets) and not 0.7 (1,369
 *                    daily buckets). Passing the daily figure used to pin the
 *                    reference line to the floor of a 0..23 axis, which looks
 *                    exactly like a chart that agrees with nothing.
 */
export function useGrowthTab(range: Range, plan: PlanFilter, grain?: Grain) {
  const effectiveGrain = useMemo(() => grain ?? autoGrain(range), [grain, range.start, range.end])

  const q = useQuery({
    queryKey: ['dash-growth', range.start, range.end, plan],
    // Keep the previous range on screen while the next one loads. Every KPI here
    // comes from a whole-table fetch, so without this a range change
    // blanks the tab and the cards briefly show zeros for the NEW range.
    placeholderData: keepPreviousData,
    queryFn: async () => {
      const [profiles, memberships, attendance] = await Promise.all([
        fetchMemberProfiles(),
        fetchMemberships(),
        fetchAttendance(range),
      ])
      return { profiles, memberships, attendance }
    },
  })

  const derived = useMemo(() => {
    const profiles = q.data?.profiles ?? []
    const memberships = q.data?.memberships
    const attendance = q.data?.attendance ?? []
    const days = Math.max(1, daysBetween(range.start, range.end))

    // One shared index for every plan lookup in this derivation. The three
    // loops below each call it once per row, and the table holds 1,860 rows.
    const planIndex = planIndexFor(memberships)

    // Members visible after the membership-type filter.
    const visible = profiles.filter(p => memberPlanMatchesIndexed(plan, planIndex, p.id))
    const createdInRange = visible.filter(p => {
      const day = p.created_at ? toDay(new Date(p.created_at)) : ''
      return day >= range.start && day <= range.end
    })

    const totalNew = createdInRange.length
    const avg = totalNew / days

    const byDay: Record<string, number> = {}
    createdInRange.forEach(p => {
      const day = toDay(new Date(p.created_at))
      byDay[day] = (byDay[day] || 0) + 1
    })
    let peakDay = ''
    let peakCount = 0
    Object.keys(byDay).forEach(d => {
      if (byDay[d] > peakCount || (byDay[d] === peakCount && d > peakDay)) {
        peakCount = byDay[d]
        peakDay = d
      }
    })

    // Members who actually visited in the range (trainers excluded), with the
    // plan resolved on the day they checked in.
    const activeIds = new Set<string>()
    attendance.forEach(r => {
      if (r.profiles?.role === 'trainer') return
      if (!planMatches(plan, resolvePlanIndexed(planIndex, r.member_id, r.check_in_date))) return
      activeIds.add(r.member_id)
    })

    // Cumulative membership size by local day used to be plotted as a second
    // line, then became an unused `total` field on every point once the
    // dual-line chart was replaced. It cost a full sort of the roster and a
    // scan of every distinct join day per bucket to compute, so it is gone
    // rather than left for the next reader to wonder about.

    const buckets = bucketize(range, effectiveGrain)
    const points: GrowthPoint[] = buckets.map(b => {
      let v = 0
      for (const day of Object.keys(byDay)) if (day >= b.start && day <= b.end) v += byDay[day]
      return { key: b.key, label: b.label, full: b.full, value: v }
    })

    // The benchmark line is drawn on the bucket axis, so it is the mean OF THE
    // BUCKETS. Dividing by the bucket count (rather than averaging `value`) is
    // the same figure without a second pass, and it stays correct when a
    // clipped first or last bucket covers a partial month.
    const avgPerBucket = buckets.length ? totalNew / buckets.length : 0

    const records: GrowthRecord[] = [...createdInRange]
      .sort((a, b) => b.created_at.localeCompare(a.created_at))
      .map(p => {
        const day = toDay(new Date(p.created_at))
        const active = memberships?.some(m => m.member_id === p.id && m.status === 'active') ?? false
        return {
          id: p.id,
          day,
          createdAt: p.created_at,
          memberName: p.full_name,
          memberCode: p.code,
          planName: resolvePlanIndexed(planIndex, p.id, day) ?? '—',
          status: active ? 'Active' : 'Inactive',
        }
      })

    return { totalNew, avg, avgPerBucket, days, peakDay, peakCount, activeCount: activeIds.size, points, records }
  }, [q.data, range.start, range.end, effectiveGrain, plan])

  return { ...derived, isLoading: q.isLoading, error: q.error }
}
