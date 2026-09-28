// Stage 3 of the unified demo seed: memberships — 60 Daily + 1,800 Monthly
// rows (1,860 total) covering all 987 members, statuses active/expired/trial
// (plan: Daily ₱60 / Monthly ₱1,800, matching MembershipsPage PLANS).
//
// Consumes the attendance manifest's per-member `windows` (coverage map) to
// decide tenure ranking, lapse state (last check-in > 45d ago ⇒ expired) and
// daily-pass days. Resumable via data/memberships.json (rows + `inserted`
// checkpoint + `asOf` generation date). Rows are upserted (ignoreDuplicates)
// in 400-row chunks.
//
// TRIAL FLOW (migration 0034): the baseline membership_status enum only has
// (active, expired, cancelled). The 60 trial rows are laid out LAST in the
// manifest, and the seed probes the enum each run: before 0034 is applied it
// inserts the 1,800 paid rows, verifies that subset, and exits 0 with a
// notice; apply supabase/migrations/0034_membership_trial_status.sql in the
// Supabase SQL editor, re-run, and the remaining 60 trial rows are added.
//
// Usage:
//   node seed-memberships.mjs              # full run (seconds)
//   node seed-memberships.mjs --dry-run    # generate + print stats, insert nothing
//
// Exit codes: 0 ok (incl. trials pending), 2 verification failed.
import {
  client, chunk, parseArgs, readManifest, writeManifest,
} from './lib/common.mjs'
import { buildMemberships, addDays } from './lib/memberships.mjs'
import { loadExistingProfiles } from './lib/users.mjs'

const KEY = 'memberships.json'
const args = parseArgs(process.argv.slice(2))
const dryRun = args['dry-run'] === true || args['dry-run'] === 'true'

function loadPeople(file) {
  const m = readManifest(file)
  const people = m?.people?.filter((p) => p.profileId) ?? []
  if (!people.length) {
    throw new Error(`${file} has no completed profiles — run seed-users.mjs first`)
  }
  return people
}

// Probe whether the live enum accepts 'trial': a fake-FK insert either gets
// rejected by the enum literal (22P02 ⇒ missing) or by the FK (23503 ⇒ ok).
async function supportsTrial() {
  const fake = 'ffffffff-ffff-4fff-8fff-ffffffffffff'
  const { error } = await client.from('memberships').insert({
    id: fake, member_id: fake, plan_name: 'Probe', price: 0,
    start_date: '2020-01-01', end_date: '2020-01-01', status: 'trial',
  })
  if (!error) {
    // No FK/enum rejection ⇒ row was actually written; remove it immediately.
    const { error: delErr } = await client.from('memberships').delete().eq('id', fake)
    if (delErr) throw new Error(`trial probe cleanup failed: ${delErr.message}`)
    return true
  }
  if (error.code === '22P02') return false // invalid enum literal ⇒ no 'trial'
  if (error.code === '23503') return true // enum accepted it, FK rejected
  throw new Error(`trial probe unexpected: ${error.code} ${error.message.split('\n')[0]}`)
}

// PostgREST caps selects at 1,000 rows — page through everything.
async function fetchAllMemberships() {
  const out = []
  for (let from = 0; ; from += 1000) {
    const { data, error } = await client
      .from('memberships').select('*').order('id', { ascending: true }).range(from, from + 999)
    if (error) throw new Error(`fetch @${from}: ${error.message}`)
    out.push(...data)
    if (data.length < 1000) break
  }
  return out
}

async function verify(expected, asOf) {
  const { count, error: cErr } = await client
    .from('memberships').select('id', { count: 'exact', head: true })
  if (cErr) throw new Error(`verify count: ${cErr.message}`)
  const rows = await fetchAllMemberships()

  const expById = new Map(expected.map((r) => [r.id, r]))
  const actById = new Map(rows.map((r) => [r.id, r]))
  let mismatch = 0
  for (const r of rows) {
    const e = expById.get(r.id)
    if (!e) { mismatch++; continue }
    if (
      r.member_id !== e.member_id || r.plan_name !== e.plan_name ||
      r.start_date !== e.start_date || r.end_date !== e.end_date ||
      r.status !== e.status || Number(r.price) !== Number(e.price)
    ) mismatch++
  }
  const missing = expected.filter((r) => !actById.has(r.id)).length

  const tally = (list, key) => {
    const o = {}
    for (const r of list) o[r[key]] = (o[r[key]] ?? 0) + 1
    return o
  }
  const expStatus = tally(expected, 'status')
  const actStatus = tally(rows, 'status')
  const expPlan = tally(expected, 'plan_name')
  const actPlan = tally(rows, 'plan_name')

  // Date coherence vs the manifest's generation date (asOf), not wall-clock —
  // a resumed run stays valid even if the calendar flipped overnight.
  const badOrder = rows.filter((r) => r.start_date > r.end_date).length
  const badActive = rows.filter(
    (r) => r.status === 'active' && !(r.start_date <= asOf && asOf <= r.end_date),
  ).length
  const badExpired = rows.filter((r) => r.status === 'expired' && !(r.end_date < asOf)).length

  const expMembers = new Set(expected.map((r) => r.member_id))
  const actMembers = new Set(rows.map((r) => r.member_id))
  const uncovered = [...expMembers].filter((id) => !actMembers.has(id)).length

  // The Memberships/Reports "expiring" panels need live supply.
  const expiring7 = rows.filter(
    (r) => r.status === 'active' && r.plan_name !== 'Daily' && r.end_date <= addDays(asOf, 7),
  ).length
  const expiring30 = rows.filter(
    (r) => r.status === 'active' && r.plan_name !== 'Daily' && r.end_date <= addDays(asOf, 30),
  ).length

  console.log('--- verification ---')
  console.log(`rows: ${count} (expected ${expected.length}) — Daily ${actPlan.Daily ?? 0}/${expPlan.Daily ?? 0}, Monthly ${actPlan.Monthly ?? 0}/${expPlan.Monthly ?? 0}`)
  console.log(`status: active ${actStatus.active ?? 0}, expired ${actStatus.expired ?? 0}, trial ${actStatus.trial ?? 0} (expected ${expStatus.active ?? 0}/${expStatus.expired ?? 0}/${expStatus.trial ?? 0})`)
  console.log(`members covered: ${actMembers.size}/${expMembers.size}`)
  console.log(`field mismatches: ${mismatch}, missing ids: ${missing}`)
  console.log(`date coherence (asOf ${asOf}): start>end ${badOrder}, active not covering ${badActive}, expired not past ${badExpired}`)
  console.log(`expiring panel supply: ≤7d ${expiring7}, ≤30d ${expiring30}`)

  const ok = (
    count === expected.length &&
    rows.length === expected.length &&
    mismatch === 0 && missing === 0 &&
    JSON.stringify(actStatus) === JSON.stringify(expStatus) &&
    JSON.stringify(actPlan) === JSON.stringify(expPlan) &&
    badOrder === 0 && badActive === 0 && badExpired === 0 &&
    uncovered === 0 &&
    expiring7 >= 1 && expiring30 >= expiring7
  )
  if (!ok) {
    console.error('VERIFY FAILED')
    process.exit(2)
  }
  console.log('VERIFY PASSED')
}

async function main() {
  const started = Date.now()

  // Same people set as the attendance stage: members.json (957 new) + the 30
  // pre-existing members. Trainers never have memberships.
  const existingMembers = loadExistingProfiles().filter((p) => p.role === 'member')
  const members = [...loadPeople('members.json'), ...existingMembers]
  if (!members.length) throw new Error('no members loaded')

  const att = readManifest('attendance.json')
  const windows = att?.windows
  if (!windows || !Object.keys(windows).length) {
    throw new Error('attendance.json has no windows — run seed-attendance.mjs first')
  }
  console.log(
    `Loaded ${members.length} members; attendance windows for ${Object.keys(windows).length} profiles`,
  )

  let manifest = readManifest(KEY)
  let rows, asOf, trialCount
  if (manifest?.rows?.length) {
    rows = manifest.rows
    asOf = manifest.asOf
    trialCount = manifest.trialCount
    console.log(
      `Resuming: generator cache hit (${rows.length} rows, asOf ${asOf}, checkpoint ${manifest.inserted ?? 0})`,
    )
  } else {
    console.log('Generating membership rows (deterministic PRNG)…')
    const t0 = Date.now()
    const out = buildMemberships(members, windows)
    rows = out.rows
    asOf = out.asOf
    trialCount = out.trialCount
    const daily = rows.filter((r) => r.plan_name === 'Daily').length
    const active = rows.filter((r) => r.status === 'active').length
    const expired = rows.filter((r) => r.status === 'expired').length
    console.log(
      `Generated ${rows.length} rows in ${((Date.now() - t0) / 1000).toFixed(1)}s as of ${asOf}: ` +
      `${daily} Daily / ${rows.length - daily} Monthly; ${active} active / ${expired} expired / ${trialCount} trial`,
    )
    writeManifest(KEY, {
      generatedAt: new Date().toISOString(),
      asOf,
      total: rows.length,
      paidCount: rows.length - trialCount,
      trialCount,
      inserted: 0,
      rows,
    })
    manifest = readManifest(KEY)
  }

  // Trial rows must sit at the very end so the checkpoint can pause before them.
  const boundary = rows.length - trialCount
  if (!rows.slice(boundary).every((r) => r.status === 'trial')) {
    throw new Error('trial rows are not all at the end of the manifest')
  }

  const trialOK = await supportsTrial()
  const effectiveTotal = trialOK ? rows.length : boundary
  console.log(
    `enum 'trial': ${trialOK ? 'supported' : 'NOT yet (apply migration 0034)'} — target ${effectiveTotal}/${rows.length} rows this run`,
  )

  if (dryRun) {
    console.log(
      `Dry run — would insert rows ${manifest.inserted ?? 0}…${effectiveTotal} ` +
      `(${trialOK ? 'everything including trials' : 'paid rows only; trials pending migration 0034'}).`,
    )
    return
  }

  const inserted = manifest.inserted ?? 0
  const pending = rows.slice(inserted, effectiveTotal)
  console.log(`Upserting ${pending.length} rows in 400-row chunks (ignoreDuplicates)…`)
  let done = inserted
  for (const c of chunk(pending, 400)) {
    const { error } = await client.from('memberships').upsert(c, { onConflict: 'id', ignoreDuplicates: true })
    if (error) throw new Error(`memberships upsert @${done}: ${error.message}`)
    done += c.length
    writeManifest(KEY, { ...readManifest(KEY), inserted: done })
  }
  console.log(`Upsert complete: ${done}/${effectiveTotal}`)

  await verify(rows.slice(0, effectiveTotal), asOf)

  if (!trialOK && trialCount > 0) {
    console.log(
      `NOTE: ${trialCount} trial rows are pending — apply ` +
      `supabase/migrations/0034_membership_trial_status.sql in the Supabase SQL editor, ` +
      `then re-run this seed to add them.`,
    )
  }
  console.log(`Total elapsed: ${((Date.now() - started) / 1000).toFixed(1)}s`)
}

main().catch((err) => {
  console.error('seed-memberships FAILED:', err.message)
  process.exit(1)
})
