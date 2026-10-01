// Re-anchor every profile's join date into [DATA_START, today].
//
// WHY THIS EXISTS
// ---------------
// `profiles` has no `joined_at` column: the join date IS `created_at`, backdated
// when the row is first inserted. `ensureProfiles()` only backdates on INSERT, and
// its upserts use `ignoreDuplicates: true` (= ON CONFLICT DO NOTHING), so a
// re-seed over existing profiles can NEVER move a join date. Changing the
// generator alone would leave every profile claiming it joined in 2020, and
// `buildAttendance` would then place check-ins years before the window the app
// offers - the failure Plan 2's Task 4 documented as "attendance silently began
// six weeks late".
//
// So the dates are moved in place with explicit UPDATEs. Nothing is deleted and
// no code is renumbered: M001 stays M001, and because the roster is ordered BY
// CODE, the "codes rise with seniority" invariant that `ensureProfiles` relies on
// is preserved.
//
// The three places that must agree are all updated here:
//   * `profiles.created_at` in the database
//   * `screenshots/demo-data/existing-profiles.json` (the hand-written showcase
//     members, which `loadExistingProfiles()` reads INSTEAD of the database)
//   * `scripts/seed/data/{members,trainers}.json` (the manifests every later seed
//     stage reads for join dates)
//
// Usage (destructive, so it must be asked for explicitly):
//   node scripts/seed/reanchor-profiles.mjs --dry-run   report only, writes nothing
//   node scripts/seed/reanchor-profiles.mjs --confirm   apply, after backing up
import { readFileSync, writeFileSync, existsSync, rmSync } from 'node:fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
import { client, DATA_START } from './lib/common.mjs'
import { planJoinedAt } from './lib/users.mjs'

const __dirname = dirname(fileURLToPath(import.meta.url))
const BACKUP_PATH = resolve(__dirname, 'data', 'joined-at-backup.json')
const EXISTING_PATH = resolve(__dirname, '..', '..', 'screenshots', 'demo-data', 'existing-profiles.json')
const MANIFESTS = ['members.json', 'trainers.json'].map((f) => resolve(__dirname, 'data', f))
const PAGE = 1000

const args = process.argv.slice(2)
const dryRun = args.includes('--dry-run')
const confirmed = args.includes('--confirm')
if (!dryRun && !confirmed) {
  console.error('Refusing to move join dates without an explicit flag.')
  console.error('  --dry-run   report the plan, write nothing')
  console.error('  --confirm   apply it (a backup of every current created_at is written first)')
  process.exit(1)
}

const codeNum = (code) => {
  const m = /^([MT])(\d+)$/.exec(code ?? '')
  return m ? { role: m[1], n: Number(m[2]) } : null
}

/** Pages the roster: PostgREST caps an unbounded select at 1,000 rows. */
async function loadProfiles() {
  const out = []
  for (let from = 0; ; from += PAGE) {
    const { data, error } = await client
      .from('profiles')
      .select('id, code, role, created_at')
      .order('code', { ascending: true })
      .range(from, from + PAGE - 1)
    if (error) throw new Error(`profiles page @${from} failed: ${error.message}`)
    out.push(...(data ?? []))
    if (!data || data.length < PAGE) return out
  }
}

const monthOf = (iso) => String(iso).slice(0, 7)

async function main() {
  console.log(`=== RE-ANCHOR PROFILES (${dryRun ? 'DRY RUN - nothing written' : 'LIVE'}) ===`)
  console.log(`Window: ${DATA_START} .. today\n`)

  const profiles = await loadProfiles()
  const members = profiles.filter((p) => codeNum(p.code)?.role === 'M').sort((a, b) => codeNum(a.code).n - codeNum(b.code).n)
  const trainers = profiles.filter((p) => codeNum(p.code)?.role === 'T').sort((a, b) => codeNum(a.code).n - codeNum(b.code).n)
  const untouched = profiles.filter((p) => !codeNum(p.code))
  console.log(`Fetched ${profiles.length} profiles: ${members.length} members, ${trainers.length} trainers, ${untouched.length} untouched (${untouched.map((p) => p.code).join(', ') || 'none'})`)

  // One END for both groups so a member and a trainer joining "now" agree.
  const END = Date.now()
  const plan = new Map()
  for (const group of [members, trainers]) {
    const dates = planJoinedAt(group.length, END)
    group.forEach((p, i) => plan.set(p.id, dates[i]))
  }

  const changes = profiles.filter((p) => plan.has(p.id) && p.created_at !== plan.get(p.id))
  console.log(`Profiles whose join date changes: ${changes.length} of ${plan.size}`)

  const byMonth = new Map()
  for (const iso of plan.values()) byMonth.set(monthOf(iso), (byMonth.get(monthOf(iso)) ?? 0) + 1)
  const months = [...byMonth.keys()].sort()
  const counts = months.map((m) => byMonth.get(m))
  console.log(`Planned join months: ${months.length} (${months[0]} .. ${months[months.length - 1]})`)
  console.log(`Per month: min ${Math.min(...counts)}, max ${Math.max(...counts)}`)
  console.log(`First 5: ${[...plan.values()].slice(0, 5).map((d) => d.slice(0, 10)).join(', ')}`)
  console.log(`Last 5:  ${[...plan.values()].slice(-5).map((d) => d.slice(0, 10)).join(', ')}`)

  if (dryRun) {
    console.log('\nDRY RUN: nothing written. Re-run with --confirm to apply.')
    return
  }

  // ---- 1. back up every current join date -------------------------------
  writeFileSync(
    BACKUP_PATH,
    JSON.stringify(
      {
        dataStart: DATA_START,
        takenAt: new Date().toISOString(),
        profiles: profiles.map((p) => ({ id: p.id, code: p.code, role: p.role, old_created_at: p.created_at })),
      },
      null,
      2,
    ),
  )
  console.log(`\nBackup written: ${BACKUP_PATH}`)

  // ---- 2. move them, one row at a time ----------------------------------
  // Individual UPDATEs rather than a batched upsert: an upsert whose payload
  // omits NOT NULL columns would try to INSERT if a row were ever missing, and
  // this must never be able to create a profile.
  let done = 0
  for (const [id, joinedAt] of plan) {
    const { error } = await client
      .from('profiles')
      .update({ created_at: joinedAt, updated_at: joinedAt })
      .eq('id', id)
    if (error) throw new Error(`update ${id} failed: ${error.message}`)
    if (++done % 200 === 0) console.log(`  ${done}/${plan.size}`)
  }
  console.log(`  ${done}/${plan.size} database rows updated`)



  // ---- 3. the hand-written showcase profiles ---------------------------
  // `loadExistingProfiles()` reads this file, NOT the database, so leaving the
  // old dates here is what silently pushed the first check-ins weeks late.
  if (existsSync(EXISTING_PATH)) {
    const text = readFileSync(EXISTING_PATH, 'utf8').replace(/^\uFEFF/, '')
    const raw = JSON.parse(text)
    const rows = Array.isArray(raw) ? raw : (raw.value ?? raw.rows ?? [])
    let touched = 0
    for (const r of rows) {
      const next = plan.get(r.id)
      if (next) {
        r.created_at = next
        touched++
      }
    }
    writeFileSync(EXISTING_PATH, JSON.stringify(Array.isArray(raw) ? rows : { ...raw, value: rows }, null, 2))
    console.log(`existing-profiles.json: ${touched} of ${rows.length} showcase rows re-anchored`)
  } else {
    console.log('existing-profiles.json not found - skipped')
  }

  // ---- 4. the seed manifests -------------------------------------------
  // Two different manifests matter here. The ROSTER manifests (members,
  // trainers) must move their join dates with the database, because every later
  // stage reads join dates from them. The STAGE manifests (attendance,
  // memberships, coach-*, notifications, predictions, renewals, enrollments)
  // cache the ENTIRE generated row array plus an `inserted` checkpoint from a
  // previous run; after a purge they are stale and would make each stage resume
  // with pre-2023 rows and skip re-inserting. Those caches are dropped so every
  // stage regenerates against the new window.
  for (const path of MANIFESTS) {
    if (!existsSync(path)) {
      console.log(`${path.split(/[\\/]/).pop()} not found - skipped`)
      continue
    }
    const manifest = JSON.parse(readFileSync(path, 'utf8').replace(/^\uFEFF/, ''))
    let touched = 0
    for (const person of manifest.people ?? []) {
      const next = plan.get(person.profileId)
      if (next) {
        person.joinedAt = next
        touched++
      }
    }
    delete manifest.inserted
    writeFileSync(path, JSON.stringify(manifest, null, 2))
    console.log(`${path.split(/[\\/]/).pop()}: ${touched} people re-anchored, 'inserted' checkpoint cleared`)
  }

  const STAGE_MANIFESTS = [
    'attendance.json', 'memberships.json', 'coach-assignments.json', 'coach-feedback.json',
    'notifications.json', 'predictions.json', 'renewals.json', 'enrollments.json',
  ].map((f) => resolve(__dirname, 'data', f))
  for (const path of STAGE_MANIFESTS) {
    if (!existsSync(path)) continue
    // Deleting is the cleanest reset: each stage rewrites its manifest on a
    // fresh generate, and none of them read a prior stage's manifest (only the
    // roster manifests, which are kept above).
    rmSync(path)
    console.log(`${path.split(/[\\/]/).pop()}: stale row cache dropped`)
  }

  // ---- 5. verify --------------------------------------------------------
  const after = await loadProfiles()
  const dates = after.filter((p) => plan.has(p.id)).map((p) => p.created_at).sort()
  const earliest = String(dates[0])
  if (earliest < DATA_START) throw new Error(`earliest join date ${earliest} precedes DATA_START ${DATA_START}`)
  if (after.length !== profiles.length) {
    throw new Error(`profile count changed ${profiles.length} -> ${after.length}`)
  }
  console.log(`\nVerified: ${after.length} profiles intact, earliest join ${earliest.slice(0, 10)} >= ${DATA_START}`)
  console.log('Now run reset-demo-data.mjs --confirm, then the seed stages.')
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
