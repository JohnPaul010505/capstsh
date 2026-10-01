import { useMemo } from 'react'
import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { autoGrain, bucketize, daysBetween, type Grain, type Range } from '@/features/dashboard/lib/dateRange'
import { fetchAttendance, fetchLastCheckins, fetchMemberships } from '@/features/dashboard/lib/attendance'
import { buildActivityFeed, type ActivityItem, type ActivityType } from '@/features/dashboard/lib/activityFeed'
import type { PlanFilter } from '@/features/dashboard/lib/planFilter'

export interface ActivityPoint {
  key: string
  label: string
  full: string
  value: number
}

/**
 * Recent Activity tab. The feed is built from the range + membership filter;
 * the activity-type dropdown filters client-side so switching it is instant
 * (no refetch, no flicker) while date/plan changes do refetch via the key.
 */
export function useActivityTab(range: Range, plan: PlanFilter, type: ActivityType | 'all', grain?: Grain) {
  const effectiveGrain = useMemo(() => grain ?? autoGrain(range), [grain, range.start, range.end])

  const q = useQuery({
    queryKey: ['dash-activity', range.start, range.end, plan],
    // Keep the previous range on screen while the next one loads. Every KPI here
    // comes from a whole-table fetch, so without this a range change
    // blanks the tab and the cards briefly show zeros for the NEW range.
    placeholderData: keepPreviousData,
    queryFn: async () => {
      const [attendance, memberships, lastCheckins] = await Promise.all([
        fetchAttendance(range),
        fetchMemberships(),
        fetchLastCheckins(),
      ])
      return buildActivityFeed({ range, plan, attendance, memberships, lastCheckins })
    },
  })

  return useMemo(() => {
    const all: ActivityItem[] = q.data ?? []
    const items = type === 'all' ? all : all.filter(i => i.type === type)

    const days = Math.max(1, daysBetween(range.start, range.end))
    const checkins = all.filter(i => i.type === 'checkin').length
    const checkouts = all.filter(i => i.type === 'checkout').length
    const people = new Set(all.map(i => `${i.memberCode ?? ''}|${i.memberName}`)).size

    const byDay: Record<string, number> = {}
    items.forEach(i => { byDay[i.day] = (byDay[i.day] || 0) + 1 })
    const buckets = bucketize(range, effectiveGrain)
    const points: ActivityPoint[] = buckets.map(b => {
      let v = 0
      for (const day of Object.keys(byDay)) if (day >= b.start && day <= b.end) v += byDay[day]
      return { key: b.key, label: b.label, full: b.full, value: v }
    })

    return {
      total: items.length,
      checkins,
      checkouts,
      people,
      days,
      points,
      records: items,
      isLoading: q.isLoading,
      error: q.error,
    }
  }, [q.data, q.isLoading, q.error, type, range.start, range.end, effectiveGrain])
}
