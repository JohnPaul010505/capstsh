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

export const ATT_ID_PREFIX = '3e01a003'

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

  for (const r of rows) delete r._checkInUtc
  return { rows, windows, minDate: rows[0]?.check_in_date ?? todayManila, maxDate: todayManila }
}
