import { useMemo } from 'react'
import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { daysBetween, toDay, type Range } from '@/features/dashboard/lib/dateRange'
import { fetchAttendance, fetchLastCheckins, fetchMemberProfiles, fetchMemberships } from '@/features/dashboard/lib/attendance'
import { memberPlanMatchesIndexed, planIndexFor, planMatches, resolvePlanIndexed, type PlanFilter } from '@/features/dashboard/lib/planFilter'

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
    // Keep the previous range on screen while the next one loads. Every KPI here
    // comes from a whole-table fetch, so without this a range change
    // blanks the tab and the cards briefly show zeros for the NEW range.
    placeholderData: keepPreviousData,
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

    // One index reused by the visibility filter, the active-set scan below and
    // the record mapping — the old code re-scanned all memberships each time.
    const planIndex = planIndexFor(memberships)

    const visible = profiles.filter(p => memberPlanMatchesIndexed(plan, planIndex, p.id))

    const activeIds = new Set<string>()
    attendance.forEach(r => {
      if (r.profiles?.role === 'trainer') return
      if (!planMatches(plan, resolvePlanIndexed(planIndex, r.member_id, r.check_in_date))) return
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

    // Gender is counted into a fixed Female/Male/Other order rather than
    // first-seen order, so the bar segments do not reshuffle between ranges
    // just because a different member happened to be listed first.
    //
    // An unrecorded gender is deliberately NOT a slice. It is an empty value,
    // not a fourth group: giving it an arc and a legend row made 3 members out
    // of 987 look like a category worth tracking, and on a card this small it
    // cost a whole row to say "nothing". It is returned as a count instead and
    // the chart shows it as a quiet note, so the information survives without
    // being promoted to a category.
    const genderCounts: Record<string, number> = { Female: 0, Male: 0, Other: 0 }
    let unrecordedGender = 0
    visible.forEach(p => {
      const label = genderLabel(p.gender)
      if (label === 'Unspecified') {
        unrecordedGender += 1
        return
      }
      genderCounts[label] = (genderCounts[label] ?? 0) + 1
    })

    // Zero-count categories are dropped rather than drawn as a 0% sliver: a
    // "Male 0" row is noise when every member is female, and an empty segment
    // still renders as a coloured pixel in the bar.
    const genderSlices: Slice[] = Object.entries(genderCounts)
      .filter(([, value]) => value > 0)
      .map(([name, value]) => ({ name, value }))

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
        planName: resolvePlanIndexed(planIndex, p.id, range.start) ?? '—',
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

    return { total: visible.length, active, inactive, newInRange, days, genderSlices, unrecordedGender, statusSlices, records }
  }, [q.data, range.start, range.end, plan])

  return { ...derived, isLoading: q.isLoading, error: q.error }
}
