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
 * rejects a select that names an unknown column outright — so the range query
 * retries without it and the column degrades to null instead of taking the
 * whole tab down (the "no widget error" guarantee).
 */
const ATTENDANCE_BASE =
  'id, member_id, check_in_time, check_in_date, check_out_time, profiles!attendance_member_id_fkey(full_name, code, role)'

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

  try {
    return await fetchAllRows<AttendanceRow>(pageOf(`${ATTENDANCE_BASE}, entry_method`))
  } catch (e) {
    if (!/entry_method|column|does not exist/i.test((e as Error).message)) throw e
    return fetchAllRows<AttendanceRow>(pageOf(ATTENDANCE_BASE))
  }
}

/** 27 rows today — small enough to fetch whole; drives the plan filter. */
export async function fetchMemberships(): Promise<MembershipLite[]> {
  const { data, error } = await supabase
    .from('memberships')
    .select('member_id, plan_name, start_date, end_date, status, price, created_at')
    .order('start_date', { ascending: true })
  if (error) throw new Error(error.message)
  return (data ?? []) as unknown as MembershipLite[]
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
