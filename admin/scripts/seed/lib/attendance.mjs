// Pure generator for the unified attendance dataset (~22k rows).
//
// Model: gym open Mon–Sat (closed Sundays, matching the business-day
// convention). Members/trainers become eligible on their join date;
// churned (is_active=false) members stop checking in after a deterministic
// churn date. Daily volume follows 2 + 22*t^1.6 (t = elapsed fraction),
// i.e. ~3/day in Jan 2020 ramping to ~24/day now — the ramp emerges from
// real member-base growth, averaging ~10.5/day over ~2,110 open days.
//
// 96% of rows belong to members, 4% to trainers. 92% of sessions are
// closed (45–180 min); today keeps 3–4 open sessions. entry_method is
// 'qr' except ~6% 'manual' (migration 0033).
// Storage convention (matches AttendancePage.tsx and the mobile calendar
// seed): check_in_time / check_out_time / expires_at are REAL UTC instants —
// the UI renders them with toLocaleTimeString() — while check_in_date is the
// Asia/Manila civil date of the check-in.
import { makeRand, uuid, localDate } from './common.mjs'

const DAY = 86400000
const PH = 8 * 3600 * 1000
// Day index d of the Manila calendar date containing instant `ms`
// (d=0 ⇔ 2020-01-01 Manila). Verified: 2026-09-26 → Sat, 2026-09-27 → Sun.
const dayIdxOfInstant = (ms) => Math.floor((ms + PH) / DAY) - Math.floor(Date.UTC(2020, 0, 0) / DAY)
// Midnight-Manila (UTC ms) starting day index d.
const dayStartUtc = (d) => (Math.floor(Date.UTC(2020, 0, 0) / DAY) + d) * DAY - PH
// Weekday of day d: noon Manila (04:00Z) — same civil day in both zones.
const dowOf = (d) => new Date(dayStartUtc(d) + 12 * 3600 * 1000).getUTCDay()
// Asia/Manila civil date of day index d.
const dateOfDay = (d) => localDate(new Date(dayStartUtc(d) + 12 * 3600 * 1000))

export const ATT_ID_PREFIX = '3e01a003'

// --- regular-attender overlay ---------------------------------------------
// The main loop above picks each day's visitors at random, so over a multi-year
// span it produces a member who visits about once a week. That is a fair
// picture of a lapsed back-catalogue, but it is the WRONG input for the
// retention model in ai-service/services/ml.py:
//
//   score = 1 - (0.6 * avg_weekly_rate + 0.2 * max(0, -trend) + 0.2 * recency)
//
// With rate 0.14 the frequency term alone gives 0.92, so every single member
// reads "high risk" and the panel's high/medium/low filter has two dead
// options. Reaching each band needs a different weekly rate:
//
//   3/wk -> rate 0.43 -> 0.74  high
//   5/wk -> rate 0.71 -> 0.57  medium
//   7/wk -> rate 1.00 -> 0.40  low    (the band test is `> 0.4`, so 0.40 is low)
//
// So we overlay a deterministic cohort of committed members on top of the
// random history, at three training intensities, PLUS a churned-regular cohort
// that trained hard in the past and then stopped. This is ADDITIVE: the main
// loop is untouched, so the 22k existing rows keep their ids and no row is
// duplicated or orphaned. A member simply attends more often recently, which
// is what a real gym's committed core looks like.
//
// Why the churned cohort is necessary: the service buckets the last 30
// check-ins by ISO week, so the FIRST bucket is always a partial week. That
// caps a 7-sessions-per-week member's avg rate at ~0.85 -> score 0.52, i.e.
// "medium". No currently-active member can reach "low" in a gym that is closed
// on Sundays. A lapsed member can: a long absence drives the recency term to
// its 0.2 maximum, so 1 - (0.6*0.857 + 0.2) = 0.29 -> "low". So the low band
// is only populated by formerly-committed members who drifted away, which is
// also exactly the population an admin's "we miss you" list is for.
export const OVERLAY_WEEKS = 12
export const REGULAR_TIERS = [
  { visitsPerWeek: 7, members: 60, offsetWeeks: 0 },   // athletes   -> medium
  { visitsPerWeek: 5, members: 90, offsetWeeks: 0 },   // committed  -> medium
  { visitsPerWeek: 3, members: 110, offsetWeeks: 0 },  // regulars   -> high
  { visitsPerWeek: 6, members: 70, offsetWeeks: 26 },  // churned    -> low
]
// Overlay members must have been members long enough to have a real history.
const OVERLAY_MIN_TENURE_DAYS = 180

const dayIdxOf = (iso) => dayIdxOfInstant(new Date(iso).getTime())


export function buildAttendance(members, trainers, opts = {}) {
  const seed = opts.seed ?? 20260928
  const { rand, randInt, pick } = makeRand(seed)
  const todayManila = opts.today ?? localDate(new Date())
  // Parse Manila midnight explicitly: dayIdxOf() adds PH internally, so a
  // naive Date.parse of the bare date would land on the wrong day index.
  const todayIdx = dayIdxOf(`${todayManila}T00:00:00+08:00`)
  // Today's sessions must look like they already happened (screenshots must
  // never show check-ins "from the future"): clamp today's check-ins to at
  // least 15 min ago. Before ~06:45 there is no 6:00→now window, so widen
  // down to midnight instead of pushing into the future.
  const nowMin = Math.floor(((Date.now() + PH) % DAY) / 60000) // since Manila midnight
  let todayLo = 6 * 60
  let todayHi = Math.min(21 * 60, nowMin - 15)
  if (todayHi < todayLo + 45) {
    todayLo = 0
    todayHi = Math.max(30, todayHi)
  }
  const totalDays = todayIdx + 1

  const eligibleMembers = members
    .filter((p) => p.profileId)
    .map((p) => {
      const joined = dayIdxOf(p.joinedAt)
      const churn = p.isActive === false
        ? joined + randInt(30, 900)
        : Number.POSITIVE_INFINITY
      return { id: p.profileId, joined, churn }
    })
  const eligibleTrainers = trainers
    .filter((p) => p.profileId)
    .map((p) => ({ id: p.profileId, joined: dayIdxOf(p.joinedAt) }))

  const rows = []
  const windows = {} // memberId -> { first, last, count }
  let idx = 0

  const touch = (id, dateStr) => {
    const w = windows[id] ?? (windows[id] = { first: dateStr, last: dateStr, count: 0 })
    if (dateStr < w.first) w.first = dateStr
    if (dateStr > w.last) w.last = dateStr
    w.count++
  }

  for (let d = 0; d <= todayIdx; d++) {
    const dow = dowOf(d)
    if (dow === 0) continue // closed Sundays
    const dateStr = localDate(new Date(dayStartUtc(d) + 12 * 3600 * 1000))
    const t = totalDays <= 1 ? 1 : d / (totalDays - 1)
    const k = Math.round(2 + 22 * Math.pow(t, 1.6))
    const isToday = d === todayIdx

    const poolM = eligibleMembers.filter((m) => m.joined <= d && d <= m.churn)
    const poolT = eligibleTrainers.filter((m) => m.joined <= d)
    if (!poolM.length && !poolT.length) continue

    const chosen = new Set()
    for (let s = 0; s < k; s++) {
      const wantTrainer = rand() >= 0.96 && poolT.length > 0
      const pool = wantTrainer ? poolT : poolM
      if (!pool.length) continue
      let person = null
      for (let attempt = 0; attempt < 3; attempt++) {
        const cand = pool[Math.floor(rand() * pool.length)]
        if (!chosen.has(cand.id)) { person = cand; break }
      }
      if (!person) continue
      chosen.add(person.id)

      const inMin = isToday
        ? randInt(todayLo, todayHi)
        : randInt(6, 21) * 60 + randInt(0, 59)
      const checkIn = new Date(dayStartUtc(d) + inMin * 60000)
      // Today: leave sessions open for now — the exact 3–4 open rule is
      // applied after the loop (close the rest). History: 8% never closed.
      const closed = isToday ? false : rand() > 0.08
      const checkOut = closed
        ? new Date(checkIn.getTime() + randInt(45, 180) * 60000)
        : null
      const row = {
        id: uuid(ATT_ID_PREFIX, idx++),
        member_id: person.id,
        check_in_time: checkIn.toISOString(), // real UTC instant (app convention)
        check_in_date: dateStr,
        check_out_time: checkOut ? checkOut.toISOString() : null,
        expires_at: new Date(checkIn.getTime() + 12 * 3600000).toISOString(),
        entry_method: rand() < 0.06 ? 'manual' : 'qr',
        _checkInUtc: checkIn.getTime(), // generator-local; stripped before insert
      }
      rows.push(row)
      if (!wantTrainer) touch(person.id, dateStr)
    }

    // Exactly 3–4 open sessions today: keep the latest check-ins open,
    // close everything else with a 45–180 min session clamped to end at
    // least 5 min before now (demo rows must never look like the future).
    if (isToday) {
      const todays = rows.filter((r) => r.check_in_date === dateStr)
      const keepOpen = randInt(3, 4)
      todays
        .sort((a, b) => (a.check_in_time < b.check_in_time ? 1 : -1))
        .forEach((r, i) => {
          if (i < Math.min(todays.length, keepOpen)) return // stay open
          const inMin = (r._checkInUtc - dayStartUtc(todayIdx)) / 60000
          const dur = Math.min(randInt(45, 180), Math.max(10, nowMin - 5 - inMin))
          r.check_out_time = new Date(r._checkInUtc + dur * 60000).toISOString()
        })
    }
  }

  // --- regular-attender overlay (additive; see REGULAR_TIERS above) ---------
  // A SEPARATE PRNG so the main loop's random stream is bit-for-bit unchanged
  // and the 22k pre-existing rows keep their ids.
  const { rand: overlayRand, randInt: overlayRandInt } = makeRand((opts.seed ?? 20260928) + 977)
  const overlayFrom = Math.max(0, todayIdx - OVERLAY_WEEKS * 7)
  // Members with real tenure and no churn date (still training).
  const candidates = eligibleMembers
    .filter((m) => m.churn === Number.POSITIVE_INFINITY && todayIdx - m.joined >= OVERLAY_MIN_TENURE_DAYS)
    .map((m) => m.id)
  // Already-checked-in days per member, so the overlay never doubles a session
  // that the random loop already created.
  const seenDays = new Map()
  for (const r of rows) {
    if (r.check_in_date < dateOfDay(overlayFrom)) continue
    const set = seenDays.get(r.member_id) ?? new Set()
    set.add(r.check_in_date)
    seenDays.set(r.member_id, set)
  }

  // One overlay session row. Every overlay session is CLOSED, including
  // today's: the "3–4 open sessions today" rule is owned by the main loop above
  // and must not be diluted by the overlay.
  const attRow = (d, inMin, durWant, durMax, memberId, dateStr, idNum) => {
    const checkIn = new Date(dayStartUtc(d) + inMin * 60000)
    const dur = Math.min(durWant, durMax)
    return {
      id: uuid(ATT_ID_PREFIX, idNum),
      member_id: memberId,
      check_in_time: checkIn.toISOString(),
      check_in_date: dateStr,
      check_out_time: new Date(checkIn.getTime() + dur * 60000).toISOString(),
      expires_at: new Date(checkIn.getTime() + 12 * 3600000).toISOString(),
      entry_method: overlayRand() < 0.06 ? 'manual' : 'qr',
    }
  }

  const pool = [...candidates]
  const churnedCutoff = new Map() // memberId -> their last legitimate check-in date
  const droppedIds = []
  let overlayRows = 0
  for (const tier of REGULAR_TIERS) {
    for (let i = 0; i < tier.members && pool.length; i++) {
      const pickAt = Math.floor(overlayRand() * pool.length)
      const memberId = pool.splice(pickAt, 1)[0]
      const seen = seenDays.get(memberId) ?? new Set()   // covered by the RANDOM loop
      seenDays.set(memberId, seen)
      // A positive offsetWeeks puts the cohort's training window in the PAST,
      // producing members who were committed and then churned.
      const tierFrom = Math.max(0, todayIdx - (tier.offsetWeeks + OVERLAY_WEEKS) * 7)
      const tierTo = todayIdx - tier.offsetWeeks * 7
      if (tierTo < tierFrom) continue
      // Quota per CALENDAR WEEK, not per day. The gym is closed on Sundays, so
      // there are only 6 open days: a 7-session week is only reachable with a
      // double session.
      for (let wStart = tierFrom; wStart <= tierTo; wStart += 7) {
        const wEnd = Math.min(wStart + 6, todayIdx)
        const openDays = []
        for (let d = wStart; d <= wEnd; d++) if (dowOf(d) !== 0) openDays.push(d)
        if (!openDays.length) continue
        // Fisher–Yates on the open days so the weekly pattern is scattered,
        // then take `visitsPerWeek` of them, wrapping to create a double day.
        const week = [...openDays]
        for (let k = week.length - 1; k > 0; k--) {
          const j = Math.floor(overlayRand() * (k + 1))
          const tmp = week[k]; week[k] = week[j]; week[j] = tmp
        }
        for (let v = 0; v < tier.visitsPerWeek; v++) {
          const d = week[v % week.length]
          const dateStr = dateOfDay(d)
          // Skip only days the RANDOM loop already covered. Overlay-added days
          // are deliberately NOT skipped, otherwise the wrap-around double
          // session that carries the 7/wk tier to rate 1.00 never happens.
          if (seen.has(dateStr)) continue
          const isSecond = v >= week.length
          const inMin = d === todayIdx
            ? overlayRandInt(todayLo, Math.max(todayLo + 30, todayHi))
            : isSecond
              ? 17 * 60 + overlayRandInt(0, 59)   // evening half of a double day
              : overlayRandInt(6, 16) * 60 + overlayRandInt(0, 59)
          const maxDur = Math.max(10, nowMin - 5 - inMin)
          rows.push(attRow(d, inMin, overlayRandInt(45, 180), maxDur, memberId, dateStr, idx++))
          touch(memberId, dateStr)
          overlayRows++
        }
      }
      if (tier.offsetWeeks > 0) churnedCutoff.set(memberId, dateOfDay(tierTo))
    }
  }

  // A churned member must have NO check-in after their window, or the random
  // loop's stray recent visit resets the retention model's recency term and the
  // member lands in "medium" instead of "low". Drop those rows and rebuild the
  // coverage map for the affected members so `windows` still describes what is
  // actually in the table.
  if (churnedCutoff.size) {
    const drop = new Set()
    for (const r of rows) {
      const cutoff = churnedCutoff.get(r.member_id)
      if (cutoff && r.check_in_date > cutoff) drop.add(r)
    }
    // Ids of rows removed from the generated set. A previous run of this seed
    // may already have written them, so the runner deletes them explicitly —
    // otherwise a churned member keeps a recent check-in in the table and the
    // retention model scores them "medium" instead of "low".
    droppedIds.push(...[...drop].map((r) => r.id))
    if (drop.size) {
      for (const r of drop) {
        const i = rows.indexOf(r)
        if (i >= 0) rows.splice(i, 1)
      }
      for (const [id] of churnedCutoff) {
        const mine = rows.filter((r) => r.member_id === id)
        if (!mine.length) { delete windows[id]; continue }
        let first = mine[0].check_in_date
        let last = mine[0].check_in_date
        for (const r of mine) {
          if (r.check_in_date < first) first = r.check_in_date
          if (r.check_in_date > last) last = r.check_in_date
        }
        windows[id] = { first, last, count: mine.length }
      }
    }
  }

  // Newest-first ids for the appended rows keeps the manifest's implied
  // chronological ordering intact.
  rows.sort((a, b) => (a.check_in_date < b.check_in_date ? -1 : 1))

  for (const r of rows) delete r._checkInUtc
  return {
    rows,
    windows,
    minDate: rows[0]?.check_in_date ?? todayManila,
    maxDate: todayManila,
    overlayRows,
    droppedIds,
  }
}

