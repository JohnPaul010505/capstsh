// Pure generator for renewals + notifications (Task 5, part 3).
//
// Migration 0027 wires an AFTER INSERT trigger (notify_membership_renewal) that
// writes one 'Membership Renewal Request' notification per admin for every
// renewal row. That trigger is live, so seeding renewals WILL produce real
// admin notifications. The notification set here is built around that fact:
// `buildNotifications` accounts for the auto-created rows and tops the list up
// with the other traffic a real gym would send, so the Notifications page (which
// reads the newest 50) is not 50 identical renewal pings.
//
// Renewals are anchored to real memberships from the Task 4 manifest: a member
// renews the plan they are actually on, and `membership_id` points at that row.
// Pending requests sit near the end of the current membership (a few days
// before it lapses); decided requests are older and carry decided_at/decided_by
// (the admin profile id, A001) as the real app would record.
//
// IDs: uuid('3e01a008', n) for renewals, uuid('3e01a009', n) for notifications.
import { makeRand, uuid, localDate } from './common.mjs'

export const RENEWAL_ID_PREFIX = '3e01a008'
export const NOTIFICATION_ID_PREFIX = '3e01a009'

export const RENEWAL_PENDING = 24
export const RENEWAL_APPROVED = 150
export const RENEWAL_DECLINED = 36
export const RENEWAL_TARGET = RENEWAL_PENDING + RENEWAL_APPROVED + RENEWAL_DECLINED

// The title the 0027 trigger hardcodes; used to model the auto-created rows.
export const RENEWAL_NOTICE_TITLE = 'Membership Renewal Request'

const DAY = 86400000
// Applied renewals extend the chain by months * 30 days for Monthly, 1 day for
// a Daily pass — the same duration the live renew path applies.
const MONTH_DAYS = 30
const RENEWAL_NOTES = [
  'Would like to continue for another block — same schedule as before.',
  'Travelling for work, pausing now and picking this back up when I am back.',
  'Please charge the same plan I am on now.',
  'Had a great run this block, happy to renew.',
  'Can I switch to a longer term? Happy with the current plan otherwise.',
  'Booking the same time slots as last month, just renewing early.',
]
const DECLINE_NOTES = [
  'Please settle the outstanding balance first, then we can renew.',
  'We will reach out next week to go through the plan options.',
  'Membership will lapse for now — the member asked us to hold off.',
]

const addDays = (iso, n) =>
  new Date(Date.parse(`${iso}T00:00:00Z`) + n * DAY).toISOString().slice(0, 10)
const dayDiff = (a, b) =>
  Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / DAY)

/** Members' real (non-trial) current memberships, latest per member. */
export function currentMemberships(rows, asOf) {
  const byMember = new Map()
  for (const r of rows) {
    if (r.status === 'trial') continue
    const prev = byMember.get(r.member_id)
    if (!prev) { byMember.set(r.member_id, r); continue }
    const covers = r.end_date >= asOf
    const prevCovers = prev.end_date >= asOf
    if (covers && !prevCovers) byMember.set(r.member_id, r)
    else if (covers === prevCovers && r.end_date > prev.end_date) byMember.set(r.member_id, r)
  }
  return [...byMember.values()]
}

/**
 * @param {Array}  memberships  Task 4 manifest rows
 * @param {string} adminId      the admin profile id (decided_by)
 * @param {{ seed?: number, today?: string }} [opts]
 */
export function buildRenewals(memberships, adminId, opts = {}) {
  const seed = opts.seed ?? 20261002
  const { randInt, pick, shuffle } = makeRand(seed)
  const asOf = opts.today ?? localDate(new Date())

  const current = shuffle(currentMemberships(memberships, asOf))
  if (current.length < RENEWAL_TARGET) {
    throw new Error(`buildRenewals: need ${RENEWAL_TARGET} current memberships, got ${current.length}`)
  }
  // Members who are actually still training apply: prefer those whose plan has
  // not already lapsed.
  const live = current.filter((m) => m.end_date >= asOf)
  const pool = live.length >= RENEWAL_TARGET ? live : current

  const out = []
  const used = new Set()
  // Exact status budget rather than a probability roll. A 11.4% roll over 210
  // rows landed 8 pending instead of the planned 24, and the pending queue is
  // the number an admin actually works from, so it must be exact.
  const plan = shuffle([
    ...Array(RENEWAL_PENDING).fill('pending'),
    ...Array(RENEWAL_APPROVED).fill('approved'),
    ...Array(RENEWAL_DECLINED).fill('declined'),
  ])
  let planIdx = 0
  for (const m of pool) {
    if (out.length >= RENEWAL_TARGET) break
    if (used.has(m.id)) continue
    used.add(m.id)
    if (planIdx >= plan.length) break
    const slack = dayDiff(asOf, m.end_date)
    // The status is consumed only once the row is actually accepted. The guards
    // below `continue` on unusable candidates, and taking it first would burn
    // budget entries on rows that never got written.
    const status = plan[planIdx]
    // Pending: applied a few days before the plan runs out. Decided: applied
    // further back, so an admin has since acted on it.
    const requestedDay = status === 'pending'
      ? addDays(m.end_date, -randInt(1, Math.max(2, Math.min(21, slack + 1))))
      : addDays(m.end_date, -randInt(22, 90))
    if (requestedDay > asOf) continue

    const months = m.plan_name === 'Daily' ? 1 : (randInt(1, 100) <= 25 ? 3 : 1)
    const decided = status !== 'pending'
    const decidedDay = decided ? addDays(requestedDay, randInt(1, 6)) : null
    if (decidedDay && decidedDay > asOf) continue

    planIdx++ // the row is accepted, so the budget entry is now consumed
    out.push({
      member_id: m.member_id,
      membership_id: m.id,
      plan_name: m.plan_name,
      months,
      status,
      note: status === 'declined' ? pick(DECLINE_NOTES) : (randInt(1, 100) <= 55 ? pick(RENEWAL_NOTES) : null),
      requested_at: new Date(`${requestedDay}T${String(randInt(8, 21)).padStart(2, '0')}:${String(randInt(0, 59)).padStart(2, '0')}:00+08:00`).toISOString(),
      decided_at: decided
        ? new Date(`${decidedDay}T${String(randInt(9, 18)).padStart(2, '0')}:${String(randInt(0, 59)).padStart(2, '0')}:00+08:00`).toISOString()
        : null,
      decided_by: decided ? adminId : null,
      // Not columns — used by the verify step to prove the anchor is coherent.
      _anchorEnd: m.end_date,
      _monthsDays: m.plan_name === 'Daily' ? 1 : months * MONTH_DAYS,
    })
  }
  out.sort((a, b) => (a.requested_at < b.requested_at ? -1 : 1))
  out.forEach((r, i) => { r.id = uuid(RENEWAL_ID_PREFIX, i) })
  return { renewals: out, asOf }
}

// Notification volume. Ruling 2: the first draft fanned 7 broadcasts out to all
// 1,076 profiles, producing 7,185 rows and burying every other notification
// type under the 50-row admin list. These two numbers set the budget instead.
export const BROADCAST_COUNT = 3
export const BROADCAST_AUDIENCE = 150
export const NUDGE_TARGET = 120

// Admin-facing broadcasts: the kind of gym announcement that goes to everyone.
const BROADCASTS = [
  { title: 'Gym closed Monday', body: 'The gym is closed on Monday for maintenance. Tuesday onward is back to normal hours.' },
  { title: 'New squat racks installed', body: 'The new racks are live on the main floor. Please re-rack your plates after every set.' },
  { title: 'Class schedule update', body: 'The 6am HIIT class moves to 7am from next week so it no longer clashes with peak hours.' },
  { title: 'Free body composition scan', body: 'Book a slot this week for the free scan. It takes ten minutes and runs on actual measurements, not estimates.' },
  { title: 'Lost property at the front desk', body: 'A water bottle and a set of keys were handed in. Come by to collect them.' },
  { title: 'Bring a friend week', body: 'Members can bring one guest free this week. Sign them in at the desk as usual.' },
  { title: 'Locker room maintenance', body: 'The far-side lockers are being repainted. Please use the near-side banks this week.' },
]
// Member-facing nudges, addressed to a specific member.
const MEMBER_NOTES = [
  { title: 'Welcome aboard', body: 'Your membership is active. Your trainer will reach out to set up your first session.' },
  { title: 'Membership expiring soon', body: 'Your plan is close to its end date. Renew from the app to keep your schedule.' },
  { title: 'We miss you', body: 'It has been a while since your last visit. Book a session and we will get you back on track.' },
  { title: 'Feedback appreciated', body: 'How is your trainer doing? A rating takes five seconds and helps us keep the coaching sharp.' },
  { title: 'New personal best?', body: 'Log your latest weigh-in so your progress and predictions stay accurate.' },
]

/**
 * Build the admin notification feed.
 *
 * The 0027 trigger creates RENEWAL_NOTICE_TITLE rows itself, so those are
 * modelled (not inserted) and counted separately. Everything else is generated
 * here. `autoRenewalCount` lets the seed subtract the rows the trigger already
 * wrote, keeping the total honest and the feed varied.
 *
 * @param {Array}  renewals   the renewal rows just seeded
 * @param {Array}  members    people with { profileId, fullName, isActive }
 * @param {string} adminId
 * @param {{ seed?: number, today?: string }} [opts]
 */
export function buildNotifications(renewals, members, adminId, opts = {}) {
  const seed = opts.seed ?? 20261003
  const { randInt, pick, shuffle } = makeRand(seed)
  const asOf = opts.today ?? localDate(new Date())
  const nameOf = new Map(members.map((m) => [m.profileId, m.fullName]))
  const rows = []

  const stamp = (day, hourMin) => new Date(`${day}T${String(hourMin[0]).padStart(2, '0')}:${String(hourMin[1]).padStart(2, '0')}:00+08:00`).toISOString()
  const backDays = (n) => addDays(asOf, -n)

  // 1. the auto-created renewal notices (trigger rows — generated for realism
  //    and reported, but NOT inserted by this seed).
  let autoRenewalCount = 0
  for (const r of renewals) {
    const name = nameOf.get(r.member_id) || 'A member'
    rows.push({
      user_id: adminId,
      title: RENEWAL_NOTICE_TITLE,
      body: `${name} requested a ${r.plan_name} membership renewal${r.months > 1 ? ` (${r.months} months)` : ''}.`,
      read: r.status !== 'pending',
      created_at: stamp(localDate(new Date(r.requested_at)), [randInt(8, 20), randInt(0, 59)]),
      _auto: true,
    })
    autoRenewalCount++
  }

  // 2. broadcasts. Deliberately NOT to all 1,076 profiles: at that fan-out the
  //    seven originals produced 7,532 rows and drowned the feed. A gym
  //    announcement reaches a segment, not the whole roster, so each broadcast
  //    goes to a sample of members plus the admin.
  const audience = shuffle(members.filter((m) => m.isActive)).slice(0, BROADCAST_AUDIENCE)
  for (let i = 0; i < BROADCAST_COUNT; i++) {
    const b = pick(BROADCASTS)
    const createdAt = stamp(backDays(randInt(2, 60)), [randInt(8, 20), randInt(0, 59)])
    for (const m of audience) {
      rows.push({ user_id: m.profileId, title: b.title, body: b.body, read: randInt(1, 100) <= 60, created_at: createdAt })
    }
    rows.push({ user_id: adminId, title: b.title, body: b.body, read: true, created_at: createdAt })
  }

  // 3. per-member nudges, plus a copy to the admin so the feed shows activity
  //    the desk needs to act on.
  const target = shuffle(members.filter((m) => m.isActive)).slice(0, NUDGE_TARGET)
  for (const m of target) {
    const note = pick(MEMBER_NOTES)
    const createdAt = stamp(backDays(randInt(1, 45)), [randInt(8, 20), randInt(0, 59)])
    rows.push({ user_id: m.profileId, title: note.title, body: note.body, read: randInt(1, 100) <= 45, created_at: createdAt })
    // Trainer/admin copy for the actionable ones ("we miss you", "expiring").
    if (note.title !== 'Welcome aboard' && randInt(1, 100) <= 60) {
      rows.push({ user_id: adminId, title: note.title, body: `${m.fullName}: ${note.body}`, read: randInt(1, 100) <= 50, created_at: createdAt })
    }
  }

  // The admin's "Recent Notifications" list is `.order('created_at', desc)
  // .limit(50)`. The 0027 trigger's renewal notices are the NEWEST rows in the
  // table, so without deliberate age-spreading the whole list would be renewal
  // notices. Push the generated rows into a spread of ages across the window so
  // the feed shows a realistic mix of announcement, nudge and renewal.
  const newest = rows.filter((r) => !r._auto).sort((a, b) => (a.created_at > b.created_at ? -1 : 1))
  newest.forEach((r, i) => {
    const spread = i < 40 ? 1 : i < 160 ? 3 : 12   // keep the freshest, age the rest
    r.created_at = stamp(backDays(spread + (i % 45)), [randInt(8, 20), randInt(0, 59)])
  })

  // Newest first (matches the page's `order('created_at', desc)`), IDs last.
  rows.sort((a, b) => (a.created_at > b.created_at ? -1 : 1))
  const insertable = rows.filter((r) => !r._auto)
  insertable.forEach((r, i) => { r.id = uuid(NOTIFICATION_ID_PREFIX, i) })

  return { insertable, autoRenewalCount, totalModelled: rows.length, asOf }
}
