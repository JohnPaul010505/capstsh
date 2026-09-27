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
