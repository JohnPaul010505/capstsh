import { supabase } from '@/lib/supabase'
import { type Range } from './dateRange'
import { cachedDataset, fetchAllRows, PAGE, type PageQuery } from './fetchAll'
import { fetchAllByDateWindows } from './windowedScan'
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

export function fetchAttendance(range: Range): Promise<AttendanceRow[]> {
  // Keyed by the range it actually filters on, so two tabs showing the same
  // dates share one fetch and two different ranges do not collide.
  return cachedDataset(`attendance:${range.start}:${range.end}`, async () => {
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
  })
}

/**
 * Every membership row, oldest start_date first; drives the plan filter.
 *
 * This used to be a single unbounded `.select()` on the strength of a comment
 * claiming "27 rows today". The unified demo seed put 1,860 rows in the table,
 * and PostgREST silently returns only the first 1,000 of an unpaged select - so
 * the plan filter was resolving against a truncated history and members were
 * being attributed to the wrong plan. It pages like every other reader here.
 */
export function fetchMemberships(): Promise<MembershipLite[]> {
  // Range-independent, and read by four of the five tabs - the single biggest
  // saving from the dataset cache.
  return cachedDataset('memberships', () =>
    fetchAllRows<MembershipLite>(async (from, to) => {
      const res = await supabase
        .from('memberships')
        .select('member_id, plan_name, start_date, end_date, status, price, created_at')
        .order('start_date', { ascending: true })
        // start_date is not unique, so a stable tiebreak is what makes the pages
        // disjoint - without it a row can appear on two pages and another can be
        // skipped entirely.
        .order('id', { ascending: true })
        .range(from, to)
      return {
        data: (res.data ?? []) as unknown as MembershipLite[],
        error: res.error ? { message: res.error.message } : null,
      }
    }),
  )
}
export function fetchLastCheckins(): Promise<Record<string, string>> {
  return cachedDataset('last-checkins', async () => {
    // The aggregate RPC does `group by member_id, max(check_in_date)` inside
    // the database, which PostgREST cannot express any other way.
    //
    // It MUST be called with explicit named arguments. Migration 0035 created
    // `member_last_checkin()`; 0036 created
    // `member_last_checkin(p_limit integer default null, p_offset integer default 0)`.
    // Because both of 0036's parameters are DEFAULTED, a zero-argument call
    // matches BOTH signatures and PostgREST refuses to choose:
    // "Could not choose the best candidate function between ...". That error is
    // silent to the user, and it pushed every dashboard load onto the date-window
    // scan below, which walks the entire attendance table one 31-day window at a
    // time - roughly 100 requests to fill a single column. Passing p_limit and
    // p_offset makes the call unambiguous and the whole read costs 2 requests.
    //
    // Paging is not optional either. PostgREST applies db-max-rows (1,000) to RPC
    // responses and IGNORES the Range header on /rpc/, so asking for everything
    // returns an arbitrary 1,000-row subset once the roster passes 1,000 distinct
    // members - it has (1,050 measured) - and the remainder would read as never
    // having visited with no error anywhere on the page. member_last_checkin_count()
    // from 0036 gives the true total to page against.
    const paged = await fetchLastCheckinsPaged()
    if (paged) return paged

    // No usable RPC (function absent, or still ambiguous on a database where 0036
    // was never applied): fall back to reading the table.
    return scanAttendanceForLastCheckin()
  })
}

/**
 * Pages the 0036 aggregate into `{ [member_id]: last_check_in }`.
 *
 * Returns `null` to mean "not usable", which is deliberately distinct from an
 * empty result: an empty attendance table and a broken RPC are different
 * situations and only the latter should drop the caller into the slow scan.
 */
async function fetchLastCheckinsPaged(): Promise<Record<string, string> | null> {
  const { data: rawTotal, error: countError } = await supabase.rpc('member_last_checkin_count')
  if (countError || rawTotal === null || rawTotal === undefined) return null
  // PostgREST returns bigint as a number on some versions and a string on others.
  const total = Number(rawTotal)
  if (!Number.isFinite(total) || total <= 0) return null

  const out: Record<string, string> = {}
  for (let offset = 0; offset < total; offset += PAGE) {
    const { data, error } = await supabase.rpc('member_last_checkin', {
      p_limit: PAGE,
      p_offset: offset,
    })
    if (error || !Array.isArray(data)) return null
    for (const r of data as { member_id: string; last_check_in: string }[]) {
      if (r?.member_id && r.last_check_in) out[r.member_id] = r.last_check_in
    }
  }
  return out
}

/** Top-level date windows in flight for the last-check-in scan. */
/**
 * Top-level date windows in flight for the last-checkin scan.
 *
 * Higher than the global paging default (4) because this scan cannot hit the
 * deep-offset ceiling that limits the others: a 31-day window holds roughly
 * 1,200 rows, so each window answers in one or two requests, at offsets 0 and
 * 1,000. Nothing here asks for offset 20,000, which is exactly the request that
 * used to return 500. The windows are independent, so this is a bounded map.
 */
const LAST_CHECKIN_SCAN_CONCURRENCY = 16

/**
 * Fallback for a database without a paged aggregate: read the attendance table
 * through date windows instead of deep offsets.
 *
 * The old version paged the whole table with `offset=0..42000`, and every offset
 * past ~35,000 answers HTTP 500 for the app's authenticated key - so the tail of
 * the table could never be read, the retries burned ~20s, and the tab sat on
 * "Loading…" or rendered with members wrongly marked as never having visited.
 * Windows keep every request at a shallow offset. The window is sized from the
 * table's own date extent, probed with two `limit=1` requests that cannot hit
 * the ceiling either.
 */
async function scanAttendanceForLastCheckin(): Promise<Record<string, string>> {
  // Two `limit=1, offset=0` probes for the table's real date extent.
  const probe = async (ascending: boolean) => {
    let q = supabase
      .from('attendance')
      .select('check_in_date')
      .order('check_in_date', { ascending })
      .limit(1)
    const res = await q
    return res.data?.[0]?.check_in_date ?? null
  }
  const min = await probe(true)
  const max = await probe(false)
  if (!min || !max) return {}

  const rows = await fetchAllByDateWindows<{ member_id: string; check_in_date: string }>(
    async (from, to, fromDay, toDay) => {
      const res = await supabase
        .from('attendance')
        .select('member_id, check_in_date')
        .gte('check_in_date', fromDay)
        .lte('check_in_date', toDay)
        .order('check_in_date', { ascending: false })
        .order('id', { ascending: false })
        .range(from, to)
      return {
        data: (res.data ?? []) as unknown as { member_id: string; check_in_date: string }[],
        error: res.error ? { message: res.error.message } : null,
      }
    },
    { from: min, to: max, windowDays: 31, concurrency: LAST_CHECKIN_SCAN_CONCURRENCY },
  )

  // `rows` is newest-window-last, so the first row seen for a member is their
  // most recent visit only within its own window. Compare dates explicitly
  // rather than relying on arrival order.
  const out: Record<string, string> = {}
  for (const r of rows) {
    if (!out[r.member_id] || r.check_in_date > out[r.member_id]) out[r.member_id] = r.check_in_date
  }
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
export function fetchMembershipsInRange(range: Range): Promise<MembershipRow[]> {
  return cachedDataset(`memberships-in-range:${range.start}:${range.end}`, () =>
  fetchAllRows<MembershipRow>(async (from, to) => {
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
  )
}

/**
 * Member profiles, newest-first. Trainers/admins are excluded — the dashboard
 * counts MEMBERS; attendance rows carry their own role flag for the
 * member/trainer split on Daily Check-ins.
 */
export function fetchMemberProfiles(): Promise<MemberProfile[]> {
  return cachedDataset('member-profiles', () =>
    fetchAllRows<MemberProfile>(async (from, to) => {
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
    }),
  )
}
