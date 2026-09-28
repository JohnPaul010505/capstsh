// Stage 2 of the unified demo seed: ~22k attendance rows (first check-in on
// the earliest join date, through today) across ALL 987 members / 89 trainers
// — the 30+7 pre-existing profiles are merged in from existing-profiles.json.
//
// Resumable: admin/scripts/seed/data/attendance.json tracks the insert
// checkpoint and carries rows + per-member `windows` {first,last,count} of
// member check-ins — the coverage map the memberships seed consumes. Rows are
// upserted (ignoreDuplicates) in 400-row chunks, so a re-run after
// interruption skips already-present ids; the attendance trigger (0028) only
// notifies for today's rows, so re-upserts of old rows never spam.
//
// Usage:
//   node seed-attendance.mjs              # full run (~1 min incl. generation)
//   node seed-attendance.mjs --dry-run    # generate + print histogram, insert nothing
//   node seed-attendance.mjs --users-only # (no-op here, kept for parity)
//
// Exit codes: 0 ok, 2 verification failed.
import { client, chunk, parseArgs, readManifest, writeManifest, localDate } from './lib/common.mjs'
import { buildAttendance, ATT_ID_PREFIX } from './lib/attendance.mjs'
import { loadExistingProfiles } from './lib/users.mjs'

const KEY = 'attendance.json'
const args = parseArgs(process.argv.slice(2))
const dryRun = args['dry-run'] === true || args['dry-run'] === 'true'

function loadPeople(file, role) {
  const m = readManifest(file)
  const people = m?.people?.filter((p) => p.profileId) ?? []
  if (!people.length) {
    throw new Error(`${file} has no completed profiles — run seed-users.mjs first`)
  }
  return people
}

async function verify(expectedTotal) {
  const { count, error } = await client.from('attendance').select('id', { count: 'exact', head: true })
  if (error) throw new Error(`verify count: ${error.message}`)
  const { data: first } = await client.from('attendance').select('check_in_date').order('check_in_date', { ascending: true }).limit(1)
  const { data: last } = await client.from('attendance').select('check_in_date').order('check_in_date', { ascending: false }).limit(1)
  const { count: openToday } = await client.from('attendance')
    .select('id', { count: 'exact', head: true })
    .eq('check_in_date', localDate(new Date()))
    .is('check_out_time', null)
  console.log('--- verification ---')
  console.log(`attendance rows: ${count} (generated ${expectedTotal})`)
  console.log(`range: ${first?.[0]?.check_in_date} → ${last?.[0]?.check_in_date}`)
  console.log(`open sessions today: ${openToday}`)
  const ok = count === expectedTotal && (openToday ?? 0) >= 3
  if (!ok) {
    console.error('VERIFY FAILED')
    process.exit(2)
  }
  console.log('VERIFY PASSED')
}

async function main() {
  const started = Date.now()
  // The dataset covers ALL 987 members / 89 trainers — the 30+7 pre-existing
  // profiles live in existing-profiles.json (not members.json), so merge them
  // in here. Their is_active flag isn't captured in the file; read it fresh.
  const existing = loadExistingProfiles()
  const existingIds = existing.map((p) => p.profileId).filter(Boolean)
  const { data: flags, error: flagErr } = await client
    .from('profiles').select('id, is_active').in('id', existingIds)
  if (flagErr) throw flagErr
  const activeById = new Map((flags ?? []).map((r) => [r.id, r.is_active]))
  for (const p of existing) p.isActive = activeById.get(p.profileId) ?? true

  const existingMembers = existing.filter((p) => p.role === 'member')
  const existingTrainers = existing.filter((p) => p.role === 'trainer')
  const members = [...loadPeople('members.json', 'member'), ...existingMembers]
  const trainers = [...loadPeople('trainers.json', 'trainer'), ...existingTrainers]
  console.log(
    `Loaded ${members.length} members + ${trainers.length} trainers with profiles ` +
    `(${existingMembers.length}+${existingTrainers.length} pre-existing kept)`,
  )

  let manifest = readManifest(KEY)
  let rows
  if (manifest?.rows?.length) {
    rows = manifest.rows
    console.log(`Resuming: generator cache hit (${rows.length} rows, checkpoint ${manifest.inserted ?? 0})`)
  } else {
    console.log('Generating attendance rows (deterministic PRNG)…')
    const t0 = Date.now()
    const out = buildAttendance(members, trainers)
    rows = out.rows
    console.log(`Generated ${rows.length} rows in ${((Date.now() - t0) / 1000).toFixed(1)}s, range ${out.minDate}→${out.maxDate}`)
    // Histogram: first month vs last month daily averages.
    const byMonth = {}
    for (const r of rows) {
      const m = r.check_in_date.slice(0, 7)
      byMonth[m] = (byMonth[m] ?? 0) + 1
    }
    const keys = Object.keys(byMonth).sort()
    const avg = (mm) => {
      const openDays = 26 // approx Mon–Sat days per month
      return (byMonth[mm] / openDays).toFixed(1)
    }
    console.log(`ramp check: ${keys[0]} avg ~${avg(keys[0])}/open-day … ${keys[keys.length - 1]} avg ~${avg(keys[keys.length - 1])}/open-day`)
    const trainerRows = rows.filter((r) => trainers.some((t) => t.profileId === r.member_id)).length
    console.log(`trainer share: ${(100 * trainerRows / rows.length).toFixed(1)}% (target ~4%)`)
    writeManifest(KEY, { generatedAt: new Date().toISOString(), total: rows.length, inserted: 0, rows, windows: out.windows })
    manifest = readManifest(KEY)
  }

  if (dryRun) {
    console.log('Dry run — inserted nothing.')
    return
  }

  const inserted = manifest.inserted ?? 0
  const pending = rows.slice(inserted)
  console.log(`Upserting ${pending.length} rows in 400-row chunks (ignoreDuplicates)…`)
  let done = inserted
  for (const c of chunk(pending, 400)) {
    const { error } = await client.from('attendance').upsert(c, { onConflict: 'id', ignoreDuplicates: true })
    if (error) throw new Error(`attendance upsert @${done}: ${error.message}`)
    done += c.length
    writeManifest(KEY, { ...readManifest(KEY), inserted: done })
    if (done % 2000 < 400) console.log(`  upserted ${done}/${rows.length}`)
  }
  console.log(`Upsert complete: ${done}/${rows.length}`)

  await verify(rows.length)
  console.log(`Total elapsed: ${((Date.now() - started) / 60000).toFixed(1)} min`)
}

main().catch((err) => {
  console.error('seed-attendance FAILED:', err.message)
  process.exit(1)
})
