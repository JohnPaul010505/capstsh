import { supabase } from '@/lib/supabase'
import { cachedDataset, fetchAllRows } from './fetchAll'
import { daysBetween, parseDay, toDay, type Range } from './dateRange'
import { planIndexFor, planMatches, resolvePlanIndexed, type MembershipLite, type PlanFilter } from './planFilter'
import { fetchMembershipsInRange, type MembershipRow } from './attendance'

/**
 * Recent Activity feed: every event is rebuilt inside the selected range so
 * changing the dates or the membership filter always changes the feed.
 *
 * Sources are the same six the dashboard always had (check-ins/check-outs,
 * memberships, enrollments, trainer assignments, expiring plans, feedback)
 * plus the derived "inactive for N days" notice — each range bounded instead
 * of `.limit(10)` on the newest rows.
 */

export type ActivityType =
  | 'checkin' | 'checkout' | 'membership' | 'enrollment'
  | 'trainer' | 'expiring' | 'feedback' | 'inactive'

export const ACTIVITY_TYPE_OPTIONS: { id: ActivityType | 'all'; label: string }[] = [
  { id: 'all', label: 'All activity types' },
  { id: 'checkin', label: 'Check-ins' },
  { id: 'checkout', label: 'Check-outs' },
  { id: 'membership', label: 'New memberships' },
  { id: 'enrollment', label: 'Enrollments' },
  { id: 'trainer', label: 'Trainer assignments' },
  { id: 'expiring', label: 'Expiring memberships' },
  { id: 'feedback', label: 'Feedback' },
  { id: 'inactive', label: 'Inactive members' },
]

export interface ActivityItem {
  id: string
  type: ActivityType
  message: string
  /** ISO instant used for ordering. */
  ts: string
  /** Local day key ('YYYY-MM-DD') used for range filtering and display. */
  day: string
  memberName: string
  memberCode: string | null
}

interface BriefProfile {
  id: string
  full_name: string
  code: string | null
  role: string
  email: string | null
}

interface Enrollment {
  id: string
  full_name: string
  email: string | null
  status: string
  created_at: string
  confirmed_at: string | null
}

interface Feedback {
  id: string
  member_id: string | null
  content: string
  created_at: string
}

interface Assignment {
  id: string
  trainer_id: string
  member_id: string
  assigned_at: string
}

const DAY = 86_400_000
const localDay = (iso: string): string => (iso ? toDay(new Date(iso)) : '')

async function paged<T>(run: (from: number, to: number) => PromiseLike<{ data: unknown[] | null; error: { message: string } | null }>): Promise<T[]> {
  return fetchAllRows<T>(async (from, to) => {
    const res = await run(from, to)
    return { data: (res.data ?? []) as T[], error: res.error }
  })
}

/**
 * A range-independent read, memoised across every activity rebuild.
 *
 * The feed re-derives on each date/plan change and each rebuild re-read all six
 * source tables. None of them depend on the range, so the second rebuild was
 * paying for six full table fetches to get the identical rows back.
 */
function pagedOnce<T>(key: string, run: (from: number, to: number) => PromiseLike<{ data: unknown[] | null; error: { message: string } | null }>): Promise<T[]> {
  return cachedDataset(key, () => paged<T>(run))
}

/** Every profile (all roles) — names/codes for activity messages. */
export function fetchBriefProfiles(): Promise<BriefProfile[]> {
  return pagedOnce<BriefProfile>('activity:brief-profiles', from =>
    supabase.from('profiles')
      .select('id, full_name, code, role, email')
      .order('created_at', { ascending: false })
      .order('id', { ascending: false })
      .range(from, from + 999),
  )
}

function fetchEnrollments(): Promise<Enrollment[]> {
  return pagedOnce<Enrollment>('activity:enrollments', from =>
    supabase.from('enrollments')
      .select('id, full_name, email, status, created_at, confirmed_at')
      .order('created_at', { ascending: false })
      .order('id', { ascending: false })
      .range(from, from + 999),
  )
}

function fetchFeedback(): Promise<Feedback[]> {
  return pagedOnce<Feedback>('activity:feedback', from =>
    supabase.from('trainer_feedback')
      .select('id, member_id, content, created_at')
      .order('created_at', { ascending: false })
      .order('id', { ascending: false })
      .range(from, from + 999),
  )
}

function fetchAssignments(): Promise<Assignment[]> {
  return pagedOnce<Assignment>('activity:assignments', from =>
    supabase.from('trainer_assignments')
      .select('id, trainer_id, member_id, assigned_at')
      .order('assigned_at', { ascending: false })
      .order('id', { ascending: false })
      .range(from, from + 999),
  )
}

export interface ActivitySource {
  range: Range
  plan: PlanFilter
  /** From fetchAttendance(range). */
  attendance: {
    id: string
    member_id: string
    check_in_time: string
    check_in_date: string
    check_out_time: string | null
    profiles: { full_name: string; code: string | null; role: string } | null
  }[]
  memberships: MembershipLite[]
  lastCheckins: Record<string, string>
}

/** One pass over every source, producing a range-filtered, plan-filtered feed. */
export async function buildActivityFeed(src: ActivitySource): Promise<ActivityItem[]> {
  const { range, plan } = src
  const [membershipRows, profiles, enrollments, feedback, assignments] = await Promise.all([
    fetchMembershipsInRange(range),
    fetchBriefProfiles(),
    fetchEnrollments(),
    fetchFeedback(),
    fetchAssignments(),
  ])

  const profileById = new Map(profiles.map(p => [p.id, p]))
  const profileByEmail = new Map(profiles.filter(p => p.email).map(p => [p.email as string, p]))

  const inRange = (day: string) => day >= range.start && day <= range.end
  // The feed calls planOk once per candidate event across six sources, so this
  // ran the full membership scan thousands of times per build. One shared index
  // turns each of those into a map lookup.
  const planIndex = planIndexFor(src.memberships)
  const planOk = (memberId: string, day: string) => planMatches(plan, resolvePlanIndexed(planIndex, memberId, day))

  const items: ActivityItem[] = []
  const nameOf = (id: string | null | undefined) => {
    const p = id ? profileById.get(id) : undefined
    return { name: p?.full_name ?? 'Unknown', code: p?.code ?? null, profile: p }
  }

  // ---- check-ins / check-outs ------------------------------------------------
  src.attendance.forEach(a => {
    if (!planOk(a.member_id, a.check_in_date)) return
    const fallback = nameOf(a.member_id)
    const memberName = a.profiles?.full_name ?? fallback.name
    const memberCode = a.profiles?.code ?? fallback.code
    items.push({
      id: `checkin-${a.id}`, type: 'checkin', message: 'Checked in',
      ts: a.check_in_time, day: a.check_in_date, memberName, memberCode,
    })
    if (a.check_out_time && inRange(localDay(a.check_out_time))) {
      items.push({
        id: `checkout-${a.id}`, type: 'checkout', message: 'Checked out',
        ts: a.check_out_time, day: localDay(a.check_out_time), memberName, memberCode,
      })
    }
  })

  // ---- new memberships (sale date = start_date, same as Revenue tab) ---------
  ;(membershipRows as MembershipRow[]).forEach(m => {
    if (plan !== 'all' && m.plan_name !== plan) return
    const { name, code } = nameOf(m.member_id)
    items.push({
      id: `membership-${m.id}`, type: 'membership',
      message: `New membership: ${m.plan_name} — ₱${(Number(m.price) || 0).toLocaleString()}`,
      ts: `${m.start_date}T12:00:00.000Z`, day: m.start_date, memberName: name, memberCode: code,
    })
  })

  // ---- enrollments -----------------------------------------------------------
  enrollments.forEach(e => {
    const day = localDay(e.created_at)
    if (!inRange(day)) return
    const profile = e.email ? profileByEmail.get(e.email) : undefined
    // A membership-type filter only makes sense for people we can resolve.
    if (plan !== 'all' && (!profile || !planOk(profile.id, day))) return
    const display = profile?.full_name ?? e.full_name
    const confirmed = e.status === 'confirmed' && e.confirmed_at
    items.push({
      id: `enrollment-${e.id}`,
      type: 'enrollment',
      message: confirmed ? `Enrollment confirmed: ${display}` : `New enrollment: ${display} (${e.email ?? 'no email'})`,
      ts: confirmed ? (e.confirmed_at as string) : e.created_at,
      day: confirmed ? localDay(e.confirmed_at as string) : day,
      memberName: display,
      memberCode: profile?.code ?? null,
    })
  })

  // ---- trainer assignments ---------------------------------------------------
  assignments.forEach(a => {
    const day = localDay(a.assigned_at)
    if (!inRange(day)) return
    if (!planOk(a.member_id, day)) return
    const trainer = nameOf(a.trainer_id)
    const member = nameOf(a.member_id)
    items.push({
      id: `assign-${a.id}`, type: 'trainer',
      message: `Assigned to ${trainer.name}`,
      ts: a.assigned_at, day, memberName: member.name, memberCode: member.code,
    })
  })

  // ---- expiring memberships (end_date inside the range) ----------------------
  src.memberships.forEach(m => {
    if (m.status !== 'active') return
    if (!inRange(m.end_date)) return
    if (plan !== 'all' && m.plan_name !== plan) return
    const { name, code } = nameOf(m.member_id)
    const past = m.end_date < range.end
    const days = Math.max(0, daysBetween(range.end, m.end_date) - 1)
    items.push({
      id: `expire-${m.member_id}-${m.end_date}-${m.plan_name}`,
      type: 'expiring',
      message: past
        ? `Membership expired ${Math.max(0, daysBetween(m.end_date, range.end) - 1)} days ago`
        : `Membership expires in ${days} days`,
      ts: `${m.end_date}T12:00:00.000Z`,
      day: m.end_date,
      memberName: name,
      memberCode: code,
    })
  })

  // ---- feedback --------------------------------------------------------------
  feedback.forEach(f => {
    const day = localDay(f.created_at)
    if (!inRange(day)) return
    if (!f.member_id || !planOk(f.member_id, day)) return
    const { name, code } = nameOf(f.member_id)
    const text = f.content ?? ''
    items.push({
      id: `feedback-${f.id}`, type: 'feedback',
      message: `New feedback: "${text.slice(0, 60)}${text.length > 60 ? '…' : ''}"`,
      ts: f.created_at, day, memberName: name, memberCode: code,
    })
  })

  // ---- inactive members (7+ days without a check-in, as of range.end) --------
  profiles.forEach(p => {
    if (p.role !== 'member') return
    const last = src.lastCheckins[p.id]
    if (!last) return
    if (!planOk(p.id, last)) return
    const becameInactive = toDay(new Date(parseDay(last).getTime() + 7 * DAY))
    if (!inRange(becameInactive)) return
    const daysInactive = Math.max(0, daysBetween(last, range.end) - 1)
    if (daysInactive < 7) return
    items.push({
      id: `inactive-${p.id}-${last}`, type: 'inactive',
      message: `Inactive for ${daysInactive} days`,
      ts: `${becameInactive}T12:00:00.000Z`, day: becameInactive,
      memberName: p.full_name, memberCode: p.code,
    })
  })

  return items.sort((a, b) => (b.ts === a.ts ? b.id.localeCompare(a.id) : b.ts.localeCompare(a.ts)))
}
