export type PlanFilter = 'all' | 'Daily' | 'Monthly'


export const PLAN_OPTIONS = [
  { id: 'Daily', label: 'Daily' },
  { id: 'Monthly', label: 'Monthly' },
] as const

export interface AttendanceRow {
  id: string
  member_id: string
  check_in_time: string
  check_in_date: string
  check_out_time: string | null
  entry_method: string | null
  profiles: { full_name: string; code: string | null; role: string } | null
}

export interface MembershipLite {
  member_id: string
  plan_name: string
  start_date: string
  end_date: string
  status: string
  price: number | null
  created_at: string
}

/**
 * Resolve a member's plan name for a given local-day date.
 * Prefers the membership whose [start_date, end_date] covers the date;
 * otherwise falls back to the member's latest membership. Returns null
 * when the member has no membership at all (e.g. trainers).
 */
export function resolvePlan(memberships: MembershipLite[] | undefined, memberId: string, day: string): string | null {
  const mine = (memberships ?? []).filter(m => m.member_id === memberId)
  if (mine.length === 0) return null
  const covering = mine.find(m => m.start_date <= day && day <= m.end_date)
  return covering ? covering.plan_name : mine[mine.length - 1].plan_name
}

/**
 * Member id -> that member's memberships, in the SAME order `resolvePlan`
 * would have seen them (the array is walked once, in place, so "the last row
 * for this member" stays the last row).
 */
export type PlanIndex = Map<string, MembershipLite[]>

/**
 * O(1) plan lookup, replacing a full scan of the membership table per lookup.
 *
 * `resolvePlan` above is correct but linear in the size of the whole
 * memberships table, and the dashboard calls it once per attendance row: the
 * unified demo data is 42,141 attendance rows against 1,860 memberships, so
 * Daily Check-ins / Member Growth / Member Overview were each doing ~78 million
 * comparisons on the MAIN thread before a single pixel of the panel could
 * render. That is the "long wait after changing the date" the panels showed.
 *
 * Building the index once and memoising it by array identity turns each lookup
 * into a map hit, so the same work drops to a few milliseconds.
 */
export function buildPlanIndex(memberships: MembershipLite[] | undefined): PlanIndex {
  const index: PlanIndex = new Map()
  for (const m of memberships ?? []) {
    const mine = index.get(m.member_id)
    if (mine) mine.push(m)
    else index.set(m.member_id, [m])
  }
  return index
}

/**
 * Memoised `buildPlanIndex`, keyed on the memberships array itself.
 *
 * Every tab re-derives its numbers in a `useMemo` that re-runs on each range or
 * filter change, and they all share the one memberships array the query
 * returned. Caching by reference means the index is built once per fetch rather
 * than once per derivation, and a `WeakMap` lets the entry be collected with the
 * array instead of pinning a 1,860-row table in memory for the app's lifetime.
 */
const planIndexCache = new WeakMap<MembershipLite[], PlanIndex>()

export function planIndexFor(memberships: MembershipLite[] | undefined): PlanIndex {
  if (!memberships || memberships.length === 0) return EMPTY_PLAN_INDEX
  const hit = planIndexCache.get(memberships)
  if (hit) return hit
  const built = buildPlanIndex(memberships)
  planIndexCache.set(memberships, built)
  return built
}

const EMPTY_PLAN_INDEX: PlanIndex = new Map()

/** `resolvePlan`, but against a prebuilt index. Same answer, no scan. */
export function resolvePlanIndexed(index: PlanIndex, memberId: string, day: string): string | null {
  const mine = index.get(memberId)
  if (!mine || mine.length === 0) return null
  // Rows are held oldest-first, so scanning forward finds the earliest
  // membership covering the day; the fallback is the newest one, matching the
  // unindexed `resolvePlan` exactly.
  for (const m of mine) {
    if (m.start_date <= day && day <= m.end_date) return m.plan_name
  }
  return mine[mine.length - 1].plan_name
}

/**
 * Membership-type filter at MEMBER level, against a prebuilt index: includes the
 * member when the filter is "all" or when ANY of their memberships is of that
 * type.
 */
export function memberPlanMatchesIndexed(plan: PlanFilter, index: PlanIndex, memberId: string): boolean {
  if (plan === 'all') return true
  const mine = index.get(memberId)
  if (!mine) return false
  for (const m of mine) if (m.plan_name === plan) return true
  return false
}

export const planMatches = (plan: PlanFilter, planName: string | null): boolean =>
  plan === 'all' || planName === plan

/**
 * Membership-type filter at MEMBER level: includes the member when the filter
 * is "all" or when ANY of their memberships is of that type. Used by the
 * Member Overview / Member Growth tabs where there is no single instant to
 * resolve a plan against the way an attendance row has.
 */
export const memberPlanMatches = (plan: PlanFilter, memberships: MembershipLite[] | undefined, memberId: string): boolean =>
  plan === 'all' || (memberships ?? []).some(m => m.member_id === memberId && m.plan_name === plan)
