import { useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { autoGrain, bucketize, daysBetween, toDay, type Grain, type Range } from '@/features/dashboard/lib/dateRange'
import { fetchAttendance, fetchMemberProfiles, fetchMemberships } from '@/features/dashboard/lib/attendance'
import {
  memberPlanMatches, planMatches, resolvePlan, type PlanFilter,
} from '@/features/dashboard/lib/planFilter'

export interface GrowthPoint {
  key: string
  label: string
  full: string
  value: number
  /** Running total of members up to the end of this bucket (second chart line). */
  total: number
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
 * plotted as daily additions plus a cumulative total (the mockup's dual-line
 * chart). The cumulative line is anchored to ALL members, not only in-range
 * ones, so it shows real membership size rather than a restart at zero.
 */
export function useGrowthTab(range: Range, plan: PlanFilter, grain?: Grain) {
  const effectiveGrain = useMemo(() => grain ?? autoGrain(range), [grain, range.start, range.end])

  const q = useQuery({
    queryKey: ['dash-growth', range.start, range.end, plan],
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

    // Members visible after the membership-type filter.
    const visible = profiles.filter(p => memberPlanMatches(plan, memberships, p.id))
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
      if (!planMatches(plan, resolvePlan(memberships, r.member_id, r.check_in_date))) return
      activeIds.add(r.member_id)
    })

    // Cumulative membership size by local day, over all visible members.
    const sorted = [...visible].sort((a, b) => a.created_at.localeCompare(b.created_at))
    const cumulativeByDay: Record<string, number> = {}
    let running = 0
    sorted.forEach(p => {
      running += 1
      cumulativeByDay[toDay(new Date(p.created_at))] = running
    })

    const buckets = bucketize(range, effectiveGrain)
    const points: GrowthPoint[] = buckets.map(b => {
      let v = 0
      for (const day of Object.keys(byDay)) if (day >= b.start && day <= b.end) v += byDay[day]
      // Cumulative size on the last day of the bucket (values only grow over time).
      let total = 0
      for (const day of Object.keys(cumulativeByDay)) {
        if (day <= b.end) total = Math.max(total, cumulativeByDay[day])
      }
      return { key: b.key, label: b.label, full: b.full, value: v, total }
    })

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
          planName: resolvePlan(memberships, p.id, day) ?? '—',
          status: active ? 'Active' : 'Inactive',
        }
      })

    return { totalNew, avg, days, peakDay, peakCount, activeCount: activeIds.size, points, records }
  }, [q.data, range.start, range.end, effectiveGrain, plan])

  return { ...derived, isLoading: q.isLoading, error: q.error }
}
