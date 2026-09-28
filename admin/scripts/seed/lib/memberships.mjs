// Pure generator for the unified memberships dataset (Task 4): 60 Daily +
// 1,800 Monthly rows (1,860 total) across every member, statuses
// active / expired / trial.
//
// Model (mirrors the live app's conventions):
//  * Plans/prices come from MembershipsPage PLANS — Daily ₱60 (1 day),
//    Monthly ₱1,800 (30 days). The create/renew path computes
//    end_date = addDays(start_date, durationDays) and chains renewals as
//    next.start = prev.end + 1, so history blocks below are laid out the same
//    way (contiguous, walking backwards from the current row).
//  * status = 'trial' for free trials (₱0, requires enum value from migration
//    0034), otherwise 'active' when end_date >= asOf else 'expired' — the same
//    boundary MembershipsPage computeStatus() derives from dates
//    (endOfDay(end) < now ⇒ expired), so stored and displayed status agree.
//  * A member is lapsed when their last check-in (attendance manifest
//    `windows`) is older than LAPSE_DAYS; their current membership then ends
//    near that last visit instead of covering today.
//  * Every member gets exactly one "base" row: Monthly current for the 927
//    non-daily users, Daily pass for the 60 daily users (30 of them the
//    pre-existing showcase members). The Monthly budget remainder (873) is
//    spent on renewal history walking backwards from the base, longest
//    tenure/highest-frequency members first, up to 2 blocks each, every block
//    >= MIN_BLOCK_DAYS and clamped to the join date.
//  * 60 trials (subset of the budgets, so totals stay 60/1,800): 45 members
//    with history get their earliest block replaced by a 3-day ₱0 signup
//    trial anchored at the join date; 15 daily users buy a ₱0 trial pass.
//
// IDs: uuid('3e01a004', n). Trial rows are assembled LAST so the seed's
// `inserted` checkpoint can stop before them while the enum lacks 'trial'
// (pre-0034) and resume afterwards.
import { makeRand, uuid, localDate } from './common.mjs'

export const MEMBERSHIP_ID_PREFIX = '3e01a004'
export const DAILY_PRICE = 60
export const MONTHLY_PRICE = 1800
export const DAILY_DAYS = 1
export const MONTHLY_DAYS = 30
export const TARGET_DAILY = 60
export const TARGET_MONTHLY = 1800
export const TRIAL_MONTHLY_COUNT = 45 // history blocks turned into signup trials
export const TRIAL_DAILY_COUNT = 15 // daily users buying a free trial pass
export const TRIAL_MONTHLY_DAYS = 3
export const LAPSE_DAYS = 45 // no check-in for this long ⇒ membership expired
export const MIN_BLOCK_DAYS = 14 // shortest plausible history block

const DAY = 86400000

// ---- Pure date helpers on YYYY-MM-DD (UTC-parsed, no TZ drift) ----
export const addDays = (iso, n) =>
  new Date(Date.parse(`${iso}T00:00:00Z`) + n * DAY).toISOString().slice(0, 10)
export const dayDiff = (a, b) =>
  Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / DAY)
// Manila civil date of an instant — matches attendance's dayIdxOf()/localDate.
const dateOf = (iso) => (iso ? localDate(new Date(iso)) : '')

// Row factory: sale moment = start_date 10:00 Manila, stored as a real UTC
// instant (same convention as the attendance timestamps).
const saleInstant = (startDate) => new Date(`${startDate}T10:00:00+08:00`).toISOString()

/**
 * @param {Array} members  people with { profileId, joinedAt, isNew, ... }
 *   (members.json people + the pre-existing members, trainers already filtered)
 * @param {Record<string,{first:string,last:string,count:number}>} windows
 *   per-member attendance coverage from the attendance manifest
 * @param {{ seed?: number, today?: string }} [opts]
 */
export function buildMemberships(members, windows, opts = {}) {
  const seed = opts.seed ?? 20260929
  const { randInt, shuffle } = makeRand(seed)
  const asOf = opts.today ?? localDate(new Date())

  // ---- Per-member stats (attendance windows drive tenure + lapse state) ----
  const stats = []
  for (const p of members) {
    if (!p.profileId) continue
    const joined = dateOf(p.joinedAt) || asOf
    const w = windows?.[p.profileId]
    const first = w?.first && w.first >= joined ? w.first : joined
    const last = w?.last && w.last >= first ? w.last : first
    stats.push({
      id: p.profileId,
      existing: p.isNew === false,
      joined,
      first,
      last,
      count: w?.count ?? 0,
      span: dayDiff(joined, last),
      activeNow: dayDiff(last, asOf) <= LAPSE_DAYS,
    })
  }
  if (!stats.length) throw new Error('no members with profiles')

  // ---- Pick the 60 daily-pass users: pre-existing showcase members first ----
  const dailyUsers = [
    ...shuffle(stats.filter((s) => s.existing)),
    ...shuffle(stats.filter((s) => !s.existing)),
  ].slice(0, TARGET_DAILY)
  if (dailyUsers.length < TARGET_DAILY) {
    throw new Error(`only ${dailyUsers.length} members for ${TARGET_DAILY} daily rows`)
  }
  const isDailyUser = new Set(dailyUsers.map((s) => s.id))
  // 15 of them buy a free trial pass (the other 45 trials come from history).
  const trialDailyIds = new Set(
    shuffle(dailyUsers).slice(0, TRIAL_DAILY_COUNT).map((s) => s.id),
  )

  // ---- Base row per member (daily pass | monthly current) ----
  const baseOf = (s) => {
    if (isDailyUser.has(s.id)) {
      const isTrial = trialDailyIds.has(s.id)
      // Active users buy today's pass; lapsed users a pass inside their own
      // attendance window, capped at today-2 so it reads as expired.
      let day = asOf
      if (!s.activeNow) {
        const inWindow = addDays(s.last, -randInt(0, 29))
        const cap = addDays(asOf, -2)
        day = inWindow < cap ? inWindow : cap
        if (day < s.joined) day = s.joined
      }
      return {
        plan_name: 'Daily',
        price: isTrial ? 0 : DAILY_PRICE,
        start_date: day,
        end_date: addDays(day, DAILY_DAYS),
        _trial: isTrial,
      }
    }
    let start, end
    if (s.activeNow) {
      // Current month covers today; randInt(0,30) keeps endings spread over
      // today..+30d (feeds the Expiring ≤7d / Ending soon ≤30d panels).
      start = addDays(asOf, -randInt(0, MONTHLY_DAYS))
      if (start < s.joined) start = s.joined
      end = addDays(start, MONTHLY_DAYS)
    } else {
      // Lapsed: expires shortly after the last visit, strictly before today.
      end = addDays(s.last, randInt(0, 14))
      if (dayDiff(asOf, end) >= 0) end = addDays(asOf, -1)
      start = addDays(end, -MONTHLY_DAYS)
      if (start < s.joined) start = s.joined
    }
    return {
      plan_name: 'Monthly',
      price: MONTHLY_PRICE,
      start_date: start,
      end_date: end,
      _trial: false,
    }
  }

  const bases = new Map(stats.map((s) => [s.id, baseOf(s)]))

  // ---- How many history blocks fit between join date and the base ----
  const capacityOf = (s) => {
    const baseStart = Date.parse(`${bases.get(s.id).start_date}T00:00:00Z`) / DAY
    const joinedN = Date.parse(`${s.joined}T00:00:00Z`) / DAY
    let end = baseStart - 1
    let n = 0
    while (n < 2) {
      const start = Math.max(joinedN, end - MONTHLY_DAYS)
      if (start > end || end - start + 1 < MIN_BLOCK_DAYS) break
      n++
      end = start - 1
    }
    return n
  }

  // ---- Allocate the history-row budget (rank by capacity, then tenure,
  // then frequency; top tier gets up to 2 blocks, next tier 1) ----
  const nonDailyCount = stats.length - dailyUsers.length
  const extrasBudget = TARGET_MONTHLY - nonDailyCount
  if (extrasBudget < 0) {
    throw new Error(
      `monthly budget exhausted: ${nonDailyCount} non-daily bases > ${TARGET_MONTHLY}`,
    )
  }
  const capCache = new Map(stats.map((s) => [s.id, capacityOf(s)]))
  const ranked = [...stats].sort(
    (a, b) =>
      capCache.get(b.id) - capCache.get(a.id) ||
      b.span - a.span ||
      b.count - a.count ||
      (a.id < b.id ? -1 : 1),
  )
  const alloc = new Map()
  let need = extrasBudget
  for (const [i, s] of ranked.entries()) {
    const want = i < 400 ? 2 : i < 473 ? 1 : 0
    const give = Math.min(want, capCache.get(s.id))
    alloc.set(s.id, give)
    need -= give
  }
  if (need > 0) {
    // Spares: hand leftovers to anyone with unused capacity, rank order.
    for (const s of ranked) {
      if (need === 0) break
      const have = alloc.get(s.id) ?? 0
      const spare = Math.min(2, capCache.get(s.id)) - have
      if (spare > 0) {
        const g = Math.min(spare, need)
        alloc.set(s.id, have + g)
        need -= g
      }
    }
  }
  if (need > 0) {
    throw new Error(`capacity exhausted: ${need}/${extrasBudget} history rows unallocated`)
  }

  // ---- 45 signup-trial members: those with history to convert ----
  const withHistory = ranked.filter((s) => (alloc.get(s.id) ?? 0) >= 1)
  const trialMonthlyIds = new Set(
    shuffle(withHistory).slice(0, TRIAL_MONTHLY_COUNT).map((s) => s.id),
  )
  if (trialMonthlyIds.size < TRIAL_MONTHLY_COUNT) {
    throw new Error(
      `only ${trialMonthlyIds.size} members with history for ${TRIAL_MONTHLY_COUNT} monthly trials`,
    )
  }

  // ---- Build history blocks (backwards from base; earliest may be the trial) ----
  const historyOf = (s) => {
    const k = alloc.get(s.id) ?? 0
    if (k === 0) return []
    const baseStart = Date.parse(`${bases.get(s.id).start_date}T00:00:00Z`) / DAY
    const joinedN = Date.parse(`${s.joined}T00:00:00Z`) / DAY
    const fmt = (n) => new Date(n * DAY).toISOString().slice(0, 10)
    const blocks = []
    let end = baseStart - 1
    for (let i = 0; i < k; i++) {
      const start = Math.max(joinedN, end - MONTHLY_DAYS)
      if (start > end || end - start + 1 < MIN_BLOCK_DAYS) break
      blocks.push({ start_date: fmt(start), end_date: fmt(end) })
      end = start - 1
    }
    if (trialMonthlyIds.has(s.id)) {
      // Replace the earliest block with a 3-day free trial at signup (the
      // rest of the paid history stays contiguous with the current row).
      blocks.pop()
      return [
        ...blocks,
        { start_date: s.joined, end_date: addDays(s.joined, TRIAL_MONTHLY_DAYS), _trial: true },
      ]
    }
    return blocks
  }

  // ---- Assemble: paid rows first (member order), trial rows LAST ----
  const paidRows = []
  const trialRows = []
  const emit = (s, r) => {
    const trial = r._trial === true
    const status = trial ? 'trial' : r.end_date >= asOf ? 'active' : 'expired'
    const row = {
      member_id: s.id,
      plan_name: r.plan_name ?? 'Monthly',
      price: r.price ?? MONTHLY_PRICE,
      start_date: r.start_date,
      end_date: r.end_date,
      status,
      created_at: saleInstant(r.start_date),
      updated_at: saleInstant(r.start_date),
    }
    ;(trial ? trialRows : paidRows).push(row)
  }
  for (const s of stats) {
    for (const h of historyOf(s)) {
      emit(s, { plan_name: 'Monthly', price: MONTHLY_PRICE, ...h })
    }
    emit(s, bases.get(s.id))
  }

  const rows = [...paidRows, ...trialRows]
  rows.forEach((r, i) => { r.id = uuid(MEMBERSHIP_ID_PREFIX, i) })

  // ---- Budget assertions (hard failures = generator bugs, not data drift) ----
  const daily = rows.filter((r) => r.plan_name === 'Daily').length
  const monthly = rows.length - daily
  if (daily !== TARGET_DAILY || monthly !== TARGET_MONTHLY) {
    throw new Error(
      `budget mismatch: daily ${daily}/${TARGET_DAILY}, monthly ${monthly}/${TARGET_MONTHLY}`,
    )
  }
  const trials = rows.filter((r) => r.status === 'trial').length
  if (trials !== TRIAL_MONTHLY_COUNT + TRIAL_DAILY_COUNT) {
    throw new Error(`trial mismatch: ${trials}/${TRIAL_MONTHLY_COUNT + TRIAL_DAILY_COUNT}`)
  }

  return { rows, asOf, paidCount: paidRows.length, trialCount: trialRows.length }
}

