import { supabase } from '@/lib/supabase'
import { type Range } from './dateRange'
import { fetchAllRows, type PageQuery } from './fetchAll'
import type { AttendanceRow, MembershipLite } from './planFilter'

/**
 * Shared, paging-complete readers for the dashboard tabs.
 *
 * PostgREST without generated DB types infers the embedded `profiles`
 * relationship as an array, so every page is awaited here and narrowed to the
 * dashboard row types in exactly one place.
 *
 * `entry_method` only exists once migration 0033 is applied, and PostgREST
 * rejects a select that names an unknown column outright — which surfaces as a
 * console error even when the app catches it. So the column is detected by
 * reading ONE row with `select=*` (a request that can never fail that way) and
 * the real select is built from the answer: the tab works before AND after the
 * migration with zero console errors either way.
 */
const ATTENDANCE_BASE =
  'id, member_id, check_in_time, check_in_date, check_out_time, profiles!attendance_member_id_fkey(full_name, code, role)'

let entryMethodProbe: Promise<boolean> | null = null

function hasEntryMethodColumn(): Promise<boolean> {
  if (!entryMethodProbe) {
    entryMethodProbe = (async () => {
      try {
        const { data, error } = await supabase.from('attendance').select('*').limit(1)
        if (error) return false
        const row = (data ?? [])[0]
        // Empty table → nothing to show either way, so the safe answer is false.
        return Boolean(row && typeof row === 'object' && 'entry_method' in row)
      } catch {
        return false
      }
    })()
  }
  return entryMethodProbe
}

export async function fetchAttendance(range: Range): Promise<AttendanceRow[]> {
  const pageOf = (select: string) => async (from: number, to: number): Promise<PageQuery<AttendanceRow>> => {
    const res = await supabase
      .from('attendance')
      .select(select)
      .gte('check_in_date', range.start)
      .lte('check_in_date', range.end)
      .order('check_in_time', { ascending: false })
      .order('id', { ascending: false })
      .range(from, to)
    return {
      data: (res.data ?? []) as unknown as AttendanceRow[],
      error: res.error ? { message: res.error.message } : null,
    }
  }

  const withEntryMethod = await hasEntryMethodColumn()
  try {
    return await fetchAllRows<AttendanceRow>(pageOf(withEntryMethod ? `${ATTENDANCE_BASE}, entry_method` : ATTENDANCE_BASE))
  } catch (e) {
    if (!/entry_method|column|does not exist/i.test((e as Error).message)) throw e
    return fetchAllRows<AttendanceRow>(pageOf(ATTENDANCE_BASE))
  }
}

/**
 * Every membership row, oldest start_date first; drives the plan filter.
 *
 * This used to be a single unbounded `.select()` on the strength of a comment
 * claiming "27 rows today". The unified demo seed put 1,860 rows in the table,
 * and PostgREST silently returns only the first 1,000 of an unpaged select — so
 * the plan filter was resolving against a truncated history and members were
 * being attributed to the wrong plan. It pages like every other reader here.
 */
export async function fetchMemberships(): Promise<MembershipLite[]> {
  return fetchAllRows<MembershipLite>(async (from, to) => {
    const res = await supabase
      .from('memberships')
      .select('member_id, plan_name, start_date, end_date, status, price, created_at')
      .order('start_date', { ascending: true })
      // start_date is not unique, so a stable tiebreak is what makes the pages
      // disjoint — without it a row can appear on two pages and another can be
      // skipped entirely.
      .order('id', { ascending: true })
      .range(from, to)
    return {
      data: (res.data ?? []) as unknown as MembershipLite[],
      error: res.error ? { message: res.error.message } : null,
    }
  })
}

/** Latest attendance day per member — 'YYYY-MM-DD', for the Member Overview tab. */
export async function fetchLastCheckins(): Promise<Record<string, string>> {
  const rows = await fetchAllRows<{ member_id: string; check_in_date: string }>(async (from, to) => {
    const res = await supabase
      .from('attendance')
      .select('member_id, check_in_date')
      .order('check_in_date', { ascending: false })
      .order('id', { ascending: false })
      .range(from, to)
    return {
      data: (res.data ?? []) as unknown as { member_id: string; check_in_date: string }[],
      error: res.error ? { message: res.error.message } : null,
    }
  })
  const out: Record<string, string> = {}
  for (const r of rows) if (!out[r.member_id]) out[r.member_id] = r.check_in_date
  return out
}

export interface MembershipRow {
  id: string
  member_id: string
  plan_name: string
  price: number | null
  start_date: string
  end_date: string
  status: string
  created_at: string
  profiles: { full_name: string; code: string | null } | null
}

export interface MemberProfile {
  id: string
  full_name: string
  code: string | null
  role: string
  gender: string | null
  email: string | null
  created_at: string
}

/**
 * Memberships whose START DAY falls inside the range — the Revenue tab's
 * transaction date. There is no payments table, and `created_at` is regularly
 * backdated far outside the period the plan actually covers, so the day the
 * membership began (start_date) is the only date that behaves like a
 * range-filterable sale date. Newest-first, ties broken by id.
 */
export async function fetchMembershipsInRange(range: Range): Promise<MembershipRow[]> {
  return fetchAllRows<MembershipRow>(async (from, to) => {
    const res = await supabase
      .from('memberships')
      .select('id, member_id, plan_name, price, start_date, end_date, status, created_at, profiles!memberships_member_id_fkey(full_name, code)')
      .gte('start_date', range.start)
      .lte('start_date', range.end)
      .order('start_date', { ascending: false })
      .order('id', { ascending: false })
      .range(from, to)
    return {
      data: (res.data ?? []) as unknown as MembershipRow[],
      error: res.error ? { message: res.error.message } : null,
    }
  })
}

/**
 * Member profiles, newest-first. Trainers/admins are excluded — the dashboard
 * counts MEMBERS; attendance rows carry their own role flag for the
 * member/trainer split on Daily Check-ins.
 */
export async function fetchMemberProfiles(): Promise<MemberProfile[]> {
  return fetchAllRows<MemberProfile>(async (from, to) => {
    const res = await supabase
      .from('profiles')
      .select('id, full_name, code, role, gender, email, created_at')
      .eq('role', 'member')
      .order('created_at', { ascending: false })
      .order('id', { ascending: false })
      .range(from, to)
    return {
      data: (res.data ?? []) as unknown as MemberProfile[],
      error: res.error ? { message: res.error.message } : null,
    }
  })
}
