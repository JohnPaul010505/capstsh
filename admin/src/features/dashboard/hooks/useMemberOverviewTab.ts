import { useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { daysBetween, toDay, type Range } from '@/features/dashboard/lib/dateRange'
import { fetchAttendance, fetchLastCheckins, fetchMemberProfiles, fetchMemberships } from '@/features/dashboard/lib/attendance'
import { memberPlanMatches, planMatches, resolvePlan, type PlanFilter } from '@/features/dashboard/lib/planFilter'

export interface MemberOverviewRecord {
  id: string
  memberName: string
  memberCode: string | null
  planName: string
  lastCheckIn: string | null
  /** Days since the last check-in, Infinity when the member never checked in. */
  daysSince: number
  genderLabel: string
  status: 'Active' | 'Inactive'
}

export interface Slice {
  name: string
  value: number
}

/**
 * Member Overview tab: who is on the books, who actually visited the selected
 * range, and who has gone quiet.
 *
 * "Active" = at least one check-in inside the range with a plan that matches
 * the filter; everyone else is inactive for that range, so narrowing the dates
 * honestly shrinks the active list.
 */
export function useMemberOverviewTab(range: Range, plan: PlanFilter) {
  const q = useQuery({
    queryKey: ['dash-members', range.start, range.end, plan],
    queryFn: async () => {
      const [profiles, memberships, attendance, lastCheckins] = await Promise.all([
        fetchMemberProfiles(),
        fetchMemberships(),
        fetchAttendance(range),
        fetchLastCheckins(),
      ])
      return { profiles, memberships, attendance, lastCheckins }
    },
  })

  const derived = useMemo(() => {
    const profiles = q.data?.profiles ?? []
    const memberships = q.data?.memberships
    const attendance = q.data?.attendance ?? []
    const lastCheckins = q.data?.lastCheckins ?? {}
    const days = Math.max(1, daysBetween(range.start, range.end))

    const visible = profiles.filter(p => memberPlanMatches(plan, memberships, p.id))

    const activeIds = new Set<string>()
    attendance.forEach(r => {
      if (r.profiles?.role === 'trainer') return
      if (!planMatches(plan, resolvePlan(memberships, r.member_id, r.check_in_date))) return
      activeIds.add(r.member_id)
    })

    const active = visible.filter(p => activeIds.has(p.id)).length
    const inactive = visible.length - active
    const newInRange = visible.filter(p => {
      const day = p.created_at ? toDay(new Date(p.created_at)) : ''
      return day >= range.start && day <= range.end
    }).length

    const genderLabel = (g: string | null) =>
      g === 'male' ? 'Male' : g === 'female' ? 'Female' : g ? 'Other' : 'Unspecified'

    const genderSlices: Slice[] = (() => {
      const counts: Record<string, number> = {}
      visible.forEach(p => {
        const label = genderLabel(p.gender)
        counts[label] = (counts[label] || 0) + 1
      })
      return Object.entries(counts).map(([name, value]) => ({ name, value }))
    })()

    const statusSlices: Slice[] = [
      { name: 'Active', value: active },
      { name: 'Inactive', value: inactive },
    ]

    const records: MemberOverviewRecord[] = visible.map(p => {
      const last = lastCheckins[p.id] ?? null
      // Inclusive day gap minus one: same day = 0 days ago.
      const daysSince = last ? Math.max(0, daysBetween(last, range.end) - 1) : Number.POSITIVE_INFINITY
      return {
        id: p.id,
        memberName: p.full_name,
        memberCode: p.code,
        planName: resolvePlan(memberships, p.id, range.start) ?? '—',
        lastCheckIn: last,
        daysSince,
        genderLabel: genderLabel(p.gender),
        status: activeIds.has(p.id) ? 'Active' : 'Inactive',
      } as MemberOverviewRecord
    }).sort((a, b) => {
      // Never-checked-in last, otherwise most recent first; ties by name.
      if (a.lastCheckIn !== b.lastCheckIn) return (b.lastCheckIn ?? '').localeCompare(a.lastCheckIn ?? '')
      return a.memberName.localeCompare(b.memberName)
    })

    return { total: visible.length, active, inactive, newInRange, days, genderSlices, statusSlices, records }
  }, [q.data, range.start, range.end, plan])

  return { ...derived, isLoading: q.isLoading, error: q.error }
}
