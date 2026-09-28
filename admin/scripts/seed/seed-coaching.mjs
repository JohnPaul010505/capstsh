// Stage 4 of the unified demo seed: the coaching + insight layer (Task 5) —
// trainer_assignments, trainer_feedback, predictions, membership_renewal_requests
// and notifications.
//
// Consumes the manifests from the earlier stages (members/trainers/attendance/
// memberships) plus the live body_measurements table, so the numbers in this
// stage are backed by the data the app actually reads. Resumable via four
// manifests in data/ (rows + `inserted` checkpoint each).
//
// Two live-database behaviours this stage must respect:
//  * Migration 0032 guards predictions at the database level (±5% weight clamp,
//    ≤95% confidence). The generator in lib/predictions.mjs reproduces ml.py's
//    maths exactly, so every row is accepted rather than rolled back.
//  * Migration 0027 fires an AFTER INSERT trigger on renewal requests that
//    writes one admin notification per renewal. Those rows are the database's
//    job, not ours, so this seed only inserts the other notifications and
//    reports the auto-created count.
//
// Usage:
//   node seed-coaching.mjs              # full run
//   node seed-coaching.mjs --dry-run    # generate + print stats, insert nothing
//   node seed-coaching.mjs --only=predictions   # one stage
//
// Exit codes: 0 ok, 2 verification failed.
import {
  client, chunk, parseArgs, readManifest, writeManifest, localDate,
} from './lib/common.mjs'
import { buildCoaching } from './lib/coaching.mjs'
import { buildPredictions, MAX_WEIGHT_CHANGE_PCT, MAX_CONFIDENCE } from './lib/predictions.mjs'
import { buildRenewals, buildNotifications, RENEWAL_TARGET } from './lib/renewals.mjs'
import { loadExistingProfiles } from './lib/users.mjs'

const KEYS = {
  assignments: 'coach-assignments.json',
  feedback: 'coach-feedback.json',
  predictions: 'predictions.json',
  renewals: 'renewals.json',
  notifications: 'notifications.json',
}
const args = parseArgs(process.argv.slice(2))
const dryRun = args['dry-run'] === true || args['dry-run'] === 'true'
const only = typeof args.only === 'string' ? args.only : null
const wants = (stage) => !only || only === stage

// ---- People, same convention as the earlier stages: the manifests hold the
// newly seeded profiles, existing-profiles.json the pre-existing ones. ----
function loadPeople(file) {
  const people = readManifest(file)?.people?.filter((p) => p.profileId) ?? []
  if (!people.length) throw new Error(`${file} has no completed profiles — run seed-users.mjs first`)
  return people
}
async function loadRoster() {
  const existing = loadExistingProfiles()
  const members = [...loadPeople('members.json'), ...existing.filter((p) => p.role === 'member')]
  const trainers = [...loadPeople('trainers.json'), ...existing.filter((p) => p.role === 'trainer')]
  if (!members.length) throw new Error('no members loaded')
  if (!trainers.length) throw new Error('no trainers loaded')
  // The live is_active flag is authoritative: the manifests were written before
  // the plan below, and this stage cares who is currently training.
  const live = new Map()
  for (let from = 0; ; from += 1000) {
    const { data, error } = await client
      .from('profiles').select('id, is_active, full_name').range(from, from + 999)
    if (error) throw new Error(`profiles @${from}: ${error.message}`)
    for (const p of data) live.set(p.id, p)
    if (data.length < 1000) break
  }
  const stamp = (p) => {
    const row = live.get(p.profileId)
    return {
      ...p,
      isActive: row ? row.is_active !== false : p.isActive !== false,
      fullName: row?.full_name || p.fullName,
    }
  }
  return { members: members.map(stamp), trainers: trainers.map(stamp) }
}

async function adminId() {
  const { data, error } = await client.from('profiles').select('id').eq('role', 'admin').limit(1)
  if (error) throw new Error(`admin lookup: ${error.message}`)
  if (!data?.length) throw new Error('no admin profile found')
  return data[0].id
}

/** Real weigh-in history per member, for the weight forecasts. */
async function loadWeights() {
  const byMember = new Map()
  for (let from = 0; ; from += 1000) {
    const { data, error } = await client
      .from('body_measurements')
      .select('member_id, weight_kg, measured_at')
      .not('weight_kg', 'is', null)
      .order('measured_at', { ascending: true })
      .range(from, from + 999)
    if (error) throw new Error(`body_measurements @${from}: ${error.message}`)
    for (const r of data) {
      const day = localDate(new Date(r.measured_at))
      if (!byMember.has(r.member_id)) byMember.set(r.member_id, [])
      byMember.get(r.member_id).push({ weight: Number(r.weight_kg), day })
    }
    if (data.length < 1000) break
  }
  return byMember
}

/**
 * ISO-8601 week number, qualified by ISO year ("2026-W31").
 * The service buckets on the bare week number, which merges week 1 of different
 * years into one bucket; qualifying with the year keeps each week distinct
 * without changing the ordering (which is by each week's earliest check-in).
 */
function isoWeek(d) {
  const t = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()))
  // Thursday of the current ISO week determines the ISO year.
  const day = (t.getUTCDay() + 6) % 7 // Monday = 0
  t.setUTCDate(t.getUTCDate() - day + 3)
  const isoYear = t.getUTCFullYear()
  const firstThursday = new Date(Date.UTC(isoYear, 0, 4))
  const firstDay = (firstThursday.getUTCDay() + 6) % 7
  firstThursday.setUTCDate(firstThursday.getUTCDate() - firstDay + 3)
  const week = 1 + Math.round((t - firstThursday) / (7 * 86400000))
  return `${isoYear}-W${String(week).padStart(2, '0')}`
}

/**
 * Weekly attendance rates per member, bucketed exactly as
 * ai-service/routers/predictions.py does: the most recent 30 check-ins, grouped
 * by ISO week, rate = min(1, check-ins / 7), ordered by each week's earliest
 * check-in (week numbers restart every January, so sorting by them would read
 * the series backwards).
 */
async function loadWeeklyAttendance() {
  const rows = []
  for (let from = 0; ; from += 1000) {
    const { data, error } = await client
      .from('attendance')
      .select('member_id, check_in_time')
      .order('check_in_time', { ascending: false })
      .range(from, from + 999)
    if (error) throw new Error(`attendance @${from}: ${error.message}`)
    rows.push(...data)
    if (data.length < 1000) break
  }

  const now = Date.now()
  const byMember = new Map()
  for (const r of rows) {
    let list = byMember.get(r.member_id)
    if (!list) { list = []; byMember.set(r.member_id, list) }
    if (list.length < 30) list.push(r.check_in_time) // most recent 30
  }

  const out = []
  for (const [memberId, times] of byMember) {
    const weeks = new Map()
    for (const t of times) {
      const d = new Date(t)
      const key = isoWeek(d)
      const slot = weeks.get(key) ?? [0, d]
      slot[0]++
      if (d < slot[1]) slot[1] = d
      weeks.set(key, slot)
    }
    const ordered = [...weeks.values()].sort((a, b) => a[1] - b[1])
    const last = new Date(times[0])
    out.push({
      memberId,
      weeklyRates: ordered.map(([count]) => Math.min(1, count / 7)),
      daysSince: Math.floor((now - last.getTime()) / 86400000),
    })
  }
  return out
}

/** Generate (or reuse) one stage's rows and upsert them with a checkpoint. */
async function runStage(stage, key, generate, verify) {
  let manifest = readManifest(key)
  let rows
  if (manifest?.rows?.length) {
    rows = manifest.rows
    console.log(`  ${stage}: resuming from manifest (${rows.length} rows, checkpoint ${manifest.inserted ?? 0})`)
  } else {
    const t0 = Date.now()
    const built = generate()
    rows = built.rows
    writeManifest(key, { generatedAt: new Date().toISOString(), total: rows.length, inserted: 0, ...built, rows })
    manifest = readManifest(key)
    console.log(`  ${stage}: generated ${rows.length} rows in ${((Date.now() - t0) / 1000).toFixed(1)}s`)
  }
  if (dryRun) {
    console.log(`  ${stage}: dry run — ${rows.length - (manifest.inserted ?? 0)} rows would be written`)
    return rows
  }

  const inserted = manifest.inserted ?? 0
  const pending = rows.slice(inserted)
  if (pending.length) {
    // Accumulate from `done`, not from `inserted`: writing `inserted + c.length`
    // on every chunk leaves the checkpoint one chunk behind after the second
    // pass, so a resumed run re-sends rows it had already written.
    let done = inserted
    for (const c of chunk(pending, 400)) {
      const { error } = await client.from(stageTable(stage)).upsert(c, { onConflict: 'id', ignoreDuplicates: true })
      if (error) throw new Error(`${stage} upsert @${done}: ${error.message}`)
      done += c.length
      writeManifest(key, { ...readManifest(key), inserted: done })
    }
  }
  console.log(`  ${stage}: ${inserted} already present, ${pending.length} written (${rows.length} total)`)
  return rows
}

const TABLE_OF = {
  assignments: 'trainer_assignments',
  feedback: 'trainer_feedback',
  predictions: 'predictions',
  renewals: 'membership_renewal_requests',
  notifications: 'notifications',
}
const stageTable = (stage) => TABLE_OF[stage]

async function fetchAll(table, columns = '*') {
  const out = []
  for (let from = 0; ; from += 1000) {
    const { data, error } = await client
      .from(table).select(columns).order('id', { ascending: true }).range(from, from + 999)
    if (error) throw new Error(`${table} @${from}: ${error.message}`)
    out.push(...data)
    if (data.length < 1000) break
  }
  return out
}

const countBy = (rows, fn) => rows.reduce((acc, r) => {
  const k = fn(r); acc[k] = (acc[k] || 0) + 1; return acc
}, {})
const avg = (nums) => (nums.length ? nums.reduce((a, b) => a + b, 0) / nums.length : 0)
const topCount = (rows, field) => Math.max(0, ...Object.values(countBy(rows, (r) => r[field])))

/**
 * Deep verification. Every check re-derives an expectation from the plan or the
 * live data rather than trusting the generator: the constraints the app and the
 * database itself rely on (unique assignment, feedback tied to an active
 * assignment, 0032's weight clamp and confidence cap, decisions stamped after
 * their request, nothing dated in the future).
 */
async function verify(ctx) {
  const problems = []
  const note = (m) => problems.push(m)
  const asOf = ctx.asOf
  const asOfInstant = Date.parse(`${asOf}T23:59:59+08:00`)

  // --- assignments ---
  const assignments = await fetchAll('trainer_assignments')
  const dupeKeys = new Set()
  let dupeCount = 0
  for (const a of assignments) {
    const k = `${a.member_id}|${a.trainer_id}|${a.status}`
    if (dupeKeys.has(k)) dupeCount++
    dupeKeys.add(k)
    if (Date.parse(a.assigned_at) > asOfInstant) note(`assignment ${a.id} is in the future`)
  }
  if (dupeCount) note(`${dupeCount} duplicate (member,trainer,status) assignments`)

  const roleOf = new Map(ctx.allProfiles.map((p) => [p.id, p.role]))
  const wrongRole = assignments.filter(
    (a) => roleOf.get(a.trainer_id) !== 'trainer' || roleOf.get(a.member_id) !== 'member',
  ).length
  if (wrongRole) note(`${wrongRole} assignments reference a non-trainer or non-member`)

  const activeAssignments = assignments.filter((a) => a.status === 'active')
  const covered = new Set(activeAssignments.map((a) => a.member_id))
  const activeMembers = ctx.members.filter((m) => m.isActive).map((m) => m.profileId)
  const uncovered = activeMembers.filter((id) => !covered.has(id)).length
  if (uncovered) note(`${uncovered} active members have no active assignment`)

  // --- feedback ---
  const feedback = await fetchAll('trainer_feedback')
  const activePair = new Set(activeAssignments.map((a) => `${a.member_id}|${a.trainer_id}`))
  // Feedback must post-date its assignment; for a member with a handover, the
  // relevant assignment is the active one.
  const assignedAtByPair = new Map()
  for (const a of assignments) {
    if (a.status === 'active') assignedAtByPair.set(`${a.member_id}|${a.trainer_id}`, a.assigned_at)
  }
  let orphan = 0
  let badRating = 0
  let badRatedAt = 0
  let future = 0
  for (const f of feedback) {
    const k = `${f.member_id}|${f.trainer_id}`
    const assignedAt = assignedAtByPair.get(k)
    if (!assignedAt) orphan++
    else if (Date.parse(f.created_at) < Date.parse(assignedAt)) orphan++
    if (f.rating != null && (f.rating < 1 || f.rating > 5)) badRating++
    if (f.rated_at && f.created_at && Date.parse(f.rated_at) <= Date.parse(f.created_at)) badRatedAt++
    if (Date.parse(f.created_at) > asOfInstant) future++
  }
  if (orphan) note(`${orphan} feedback rows without an active assignment (or dated before it)`)
  if (badRating) note(`${badRating} feedback ratings outside 1..5`)
  if (badRatedAt) note(`${badRatedAt} feedback rows rated before they were written`)
  if (future) note(`${future} feedback rows dated in the future`)

  // --- predictions: re-check migration 0032's guards independently ---
  const predictions = await fetchAll('predictions')
  let bounds = 0
  let conf = 0
  let bodyFat = 0
  let noUnit = 0
  for (const p of predictions) {
    if (p.metric_name === 'body_fat') { bodyFat++; continue }
    if (p.metric_name === 'weight' && p.current_value != null) {
      const lo = Math.max(p.current_value * (1 - MAX_WEIGHT_CHANGE_PCT), 0.5)
      const hi = p.current_value * (1 + MAX_WEIGHT_CHANGE_PCT)
      if (p.predicted_value < lo - 1e-6 || p.predicted_value > hi + 1e-6) bounds++
      if (p.confidence > MAX_CONFIDENCE + 1e-6) conf++
    }
    if (p.metric_name === 'retention_risk' && (p.predicted_value < 0 || p.predicted_value > 1)) bounds++
    if (!p.unit) noUnit++
  }
  if (bounds) note(`${bounds} predictions outside their plausible bounds`)
  if (conf) note(`${conf} weight predictions exceed 95% confidence`)
  if (bodyFat) note(`${bodyFat} body_fat predictions (the app filters these out)`)
  if (noUnit) note(`${noUnit} predictions missing a unit`)

    // --- renewals ---
  const renewals = await fetchAll('membership_renewal_requests')
  const membershipById = new Map(ctx.membershipRows.map((m) => [m.id, m]))
  const counts = { pending: 0, approved: 0, declined: 0 }
  let planMismatch = 0
  let badDecision = 0
  let decidedEarly = 0
  let futureReq = 0
  for (const r of renewals) {
    counts[r.status] = (counts[r.status] || 0) + 1
    const m = membershipById.get(r.membership_id)
    if (!m || m.plan_name !== r.plan_name) planMismatch++
    const decided = r.status !== 'pending'
    if (decided !== Boolean(r.decided_at) || decided !== Boolean(r.decided_by)) badDecision++
    if (r.decided_at && Date.parse(r.decided_at) < Date.parse(r.requested_at)) decidedEarly++
    if (Date.parse(r.requested_at) > asOfInstant) futureReq++
  }
  if (planMismatch) note(`${planMismatch} renewals whose membership_id does not match plan_name`)
  if (badDecision) note(`${badDecision} renewals with an inconsistent decision stamp`)
  if (decidedEarly) note(`${decidedEarly} renewals decided before they were requested`)
  if (futureReq) note(`${futureReq} renewals requested in the future`)
  if (!counts.pending) note('no pending renewals — the Memberships page needs a live queue')

  // --- notifications ---
  const notifications = await fetchAll('notifications')
  const autoNotices = notifications.filter((n) => n.title === 'Membership Renewal Request').length
  const futureNotices = notifications.filter((n) => Date.parse(n.created_at) > Date.now() + 60000).length
  if (futureNotices) note(`${futureNotices} notifications dated in the future`)

  const rated = feedback.filter((f) => f.rating != null).map((f) => f.rating)
  const riskRows = predictions.filter((p) => p.metric_name === 'retention_risk')
  console.log('\n--- verify ---')
  console.log(`assignments: ${assignments.length} (${activeAssignments.length} active / ${assignments.length - activeAssignments.length} ended)`)
  console.log(`  active members covered: ${activeMembers.length - uncovered}/${activeMembers.length} · busiest trainer: ${topCount(assignments, 'trainer_id')} · most-assisted member: ${topCount(activeAssignments, 'member_id')}`)
  console.log(`feedback: ${feedback.length} · rated ${rated.length} · avg rating ${avg(rated).toFixed(2)} · by ${new Set(feedback.map((f) => f.trainer_id)).size} trainers`)
  console.log(`predictions: ${predictions.length} (weight ${predictions.filter((p) => p.metric_name === 'weight').length} / retention_risk ${riskRows.length})`)
  console.log(`  risk bands: ${JSON.stringify(countBy(riskRows, (p) => (p.note || '').match(/risk level (\w+)/)?.[1] ?? '?'))}`)
  console.log(`renewals: ${renewals.length} · ${JSON.stringify(counts)}`)
  console.log(`notifications: ${notifications.length} — ${autoNotices} auto renewal notices from the 0027 trigger, ${new Set(notifications.map((n) => n.title)).size} distinct titles`)

  if (problems.length) {
    console.error('\nVERIFY FAILED:')
    for (const p of problems) console.error(`  - ${p}`)
    process.exit(2)
  }
  console.log('VERIFY PASSED')
}

async function main() {
  const started = Date.now()
  const { members, trainers } = await loadRoster()
  const windows = readManifest('attendance.json')?.windows
  if (!windows || !Object.keys(windows).length) {
    throw new Error('attendance.json has no windows — run seed-attendance.mjs first')
  }
  const memManifest = readManifest('memberships.json')
  const membershipRows = memManifest?.rows
  if (!membershipRows?.length) {
    throw new Error('memberships.json has no rows — run seed-memberships.mjs first')
  }
  const asOf = memManifest.asOf
  console.log(`Loaded ${members.length} members (${members.filter((m) => m.isActive).length} active) + ${trainers.length} trainers · asOf ${asOf}`)

  if (wants('assignments') || wants('feedback')) {
    const built = buildCoaching(members, trainers, windows, { today: asOf })
    const aRows = await runStage('assignments', KEYS.assignments, () => ({ rows: built.assignments, asOf: built.asOf }))
    const fRows = await runStage('feedback', KEYS.feedback, () => ({ rows: built.feedback, asOf: built.asOf }))
    console.log(`  assignments: ${aRows.filter((a) => a.status === 'active').length} active / ${aRows.filter((a) => a.status === 'ended').length} ended · feedback: ${fRows.length}`)
  }

  if (wants('predictions')) {
    const weights = await loadWeights()
    const weekly = await loadWeeklyAttendance()
    const built = buildPredictions(weights, weekly, { today: asOf })
    // `_`-prefixed keys are generator-local (same convention as attendance's
    // `_checkInUtc`) and are not columns — strip them before the insert.
    const insertable = built.rows.map(({ _basis, ...row }) => row)
    await runStage('predictions', KEYS.predictions, () => ({ rows: insertable, asOf: built.asOf, bands: built.bands }))
    console.log(`  weight rows: ${built.rows.filter((r) => r.metric_name === 'weight').length} (${weights.size} members have weigh-ins, ${built.skippedWeights} too thin) · risk bands ${JSON.stringify(built.bands)}`)
  }

  if (wants('renewals') || wants('notifications')) {
    const admin = await adminId()
    const renewals = buildRenewals(membershipRows, admin, { today: asOf }).renewals
    // `_`-prefixed keys are generator-local proof fields, not columns.
    const rInsertable = renewals.map(({ _anchorEnd, _monthsDays, ...row }) => row)
    const rRows = await runStage('renewals', KEYS.renewals, () => ({ rows: rInsertable, asOf }))
    const built = buildNotifications(rRows, members, admin, { today: asOf })
    await runStage('notifications', KEYS.notifications, () => ({
      rows: built.insertable, asOf: built.asOf, autoRenewalCount: built.autoRenewalCount,
    }))
    console.log(`  renewals: ${rRows.length} · notifications: ${built.insertable.length} inserted + ${built.autoRenewalCount} auto-created by the 0027 trigger`)
  }

  if (dryRun) { console.log('\nDry run — nothing written.'); return }
  if (only) {
    console.log(`\nStage '${only}' written in ${((Date.now() - started) / 1000).toFixed(1)}s (deep verify runs on full runs only).`)
    return
  }

  const allProfiles = []
  for (let from = 0; ; from += 1000) {
    const { data, error } = await client.from('profiles').select('id, role').range(from, from + 999)
    if (error) throw new Error(`profiles @${from}: ${error.message}`)
    allProfiles.push(...data)
    if (data.length < 1000) break
  }
  await verify({ asOf, members, membershipRows, allProfiles })
  console.log(`\nDone in ${((Date.now() - started) / 1000).toFixed(1)}s`)
}

main().catch((err) => {
  console.error(`\nseed-coaching failed: ${err.message}`)
  process.exit(1)
})
