// Stage 1 of the unified demo seed: create auth users + profiles for
// 957 new members + 82 new trainers (all @demo.fit / MockPass123!).
//
// Two phases per role (passes joinedAt-ascending so trigger codes rise
// with seniority): A) auth.createUser at concurrency 4 (manifest
// checkpointed every 25); B) sequential profile inserts (no `code` —
// the auto_uid trigger assigns the next M/T number; created_at/updated_at
// then backdated to joinedAt for the Member Growth chart).
//
// Resumable: manifests in admin/scripts/seed/data/*.json are the
// checkpoint. Re-runs adopt existing auth users (email_exists) and
// existing profiles (lookup by email) without creating duplicates.
//
// Usage:
//   node seed-users.mjs --limit 20          # smoke test, cheapest 20
//   node seed-users.mjs --members-only
//   node seed-users.mjs --trainers-only
//   node seed-users.mjs                      # full run (~25 min)
//   node seed-users.mjs --users-only         # skip verification
//   node seed-users.mjs --verify-only        # just run verification
//
// Exit codes: 0 ok, 2 verification failed (--users-only not set).
import { client, parseArgs, readManifest, writeManifest } from './lib/common.mjs'
import {
  buildMembers, buildTrainers, loadExistingProfiles, KNOWN_CODE_GAPS,
  ensureAuthUsers, ensureProfiles,
} from './lib/users.mjs'

const TARGET_MEMBERS = 957
const TARGET_TRAINERS = 82
const MEMBERS_KEY = 'members.json'
const TRAINERS_KEY = 'trainers.json'

const args = parseArgs(process.argv.slice(2))
const strVal = (v) => (typeof v === 'string' ? v : null)
const boolVal = (v) => v === true || v === 'true'
const limitRaw = strVal(args.limit)
const limit = limitRaw ? parseInt(limitRaw, 10) : 0
const verifyOnly = boolVal(args['verify-only'])
const usersOnly = boolVal(args['users-only'])
const onlyMembers = boolVal(args['members-only'])
const onlyTrainers = boolVal(args['trainers-only'])

function loadOrBuild(key, builder, target) {
  const existing = readManifest(key)
  if (existing?.people?.length) {
    console.log(`Resuming ${key}: ${existing.people.filter((p) => p.profileId).length}/${existing.people.length} profiles done`)
    return existing.people
  }
  const people = builder(target)
  writeManifest(key, { target, builtAt: new Date().toISOString(), people })
  console.log(`Built ${people.length} deterministic ${key} entries (seeded PRNG, joinedAt 2020-01-01→today, ascending)`)
  return people
}

function save(key, people, target) {
  writeManifest(key, { target, updatedAt: new Date().toISOString(), people })
}

function progress(done, total, label) {
  if (done % 50 === 0 || done === total) console.log(`  [${label}] ${done}/${total}`)
}

async function seedRole(kind, role, key, builder, target, count) {
  let people = loadOrBuild(key, builder, target)
  if (limit > 0) {
    // Deterministic slice: cheapest (oldest) N first so smoke tests mirror
    // the real distribution tail.
    people = [...people].sort((a, b) => (a.joinedAt < b.joinedAt ? -1 : 1)).slice(0, Math.min(limit, people.length))
    console.log(`--limit ${limit}: seeding oldest ${people.length} ${kind} only (manifest not overwritten globally)`)
  }
  const t0 = Date.now()
  console.log(`Stage A — auth users for ${people.length} ${kind} (concurrency 4)…`)
  const persist = limit > 0 ? null : () => save(key, people, target)
  await ensureAuthUsers(people, {
    onSave: persist,
    onProgress: (d, t) => progress(d, t, `${kind}/auth`),
  })
  console.log(`Stage B — profiles for ${people.length} ${kind} (sequential, trigger codes)…`)
  await ensureProfiles(people, role, {
    onSave: persist,
    onProgress: (d, t) => progress(d, t, `${kind}/profile`),
  })
  const dt = ((Date.now() - t0) / 1000).toFixed(1)
  console.log(`Done ${kind}: ${people.filter((p) => p.profileId).length}/${people.length} profiles in ${dt}s`)
  return people
}

async function verify() {
  const { count: members } = await client.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'member')
  const { count: trainers } = await client.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'trainer')
  const { data: dupEmails } = await client.from('profiles').select('email')
  const seen = new Set()
  let dup = 0
  for (const r of dupEmails ?? []) {
    if (seen.has(r.email)) dup++
    seen.add(r.email)
  }
  const { data: dupCodes } = await client.from('profiles').select('code').not('code', 'is', null)
  const seenCode = new Set()
  let dupCode = 0
  for (const r of dupCodes ?? []) {
    if (seenCode.has(r.code)) dupCode++
    seenCode.add(r.code)
  }
  const expMembers = 30 + (limit > 0 ? 0 : TARGET_MEMBERS)
  const expTrainers = 7 + (limit > 0 ? 0 : TARGET_TRAINERS)
  console.log('--- verification ---')
  console.log(`members:  ${members} (existing 30 + new ${limit > 0 ? '(limit run)' : TARGET_MEMBERS})`)
  console.log(`trainers: ${trainers} (existing 7 + new ${limit > 0 ? '(limit run)' : TARGET_TRAINERS})`)
  console.log(`duplicate emails: ${dup} | duplicate codes: ${dupCode}`)
  console.log(`known code gaps (deleted probes, expected): ${KNOWN_CODE_GAPS.join(', ')}`)
  if (!limit) {
    const ok = members >= expMembers && trainers >= expTrainers && dup === 0 && dupCode === 0
    if (!ok) {
      console.error(`VERIFY FAILED: expected >= ${expMembers} members and >= ${expTrainers} trainers with 0 dupes`)
      process.exit(2)
    }
    console.log('VERIFY PASSED')
  } else {
    console.log('(limit run — full expectations checked on the final full run)')
  }
}

async function main() {
  const started = Date.now()
  if (!verifyOnly) {
    if (!onlyTrainers) await seedRole('members', 'member', MEMBERS_KEY, (n) => buildMembers(n), TARGET_MEMBERS)
    if (!onlyMembers) await seedRole('trainers', 'trainer', TRAINERS_KEY, (n) => buildTrainers(n), TARGET_TRAINERS)
  }
  const existing = loadExistingProfiles()
  console.log(`Existing profiles kept: ${existing.length} (30 members incl. M001/M002, 7 trainers, 1 admin)`)
  if (!usersOnly || verifyOnly || limit > 0) await verify()
  else console.log('Skipped verification (--users-only). Run with --verify-only to check.')
  if (!limit && (onlyMembers || onlyTrainers)) {
    console.log('NOTE: partial role run — run the complementary flag to finish, then --verify-only.')
  }
  console.log(`Total elapsed: ${((Date.now() - started) / 60000).toFixed(1)} min`)
}

main().catch((err) => {
  console.error('seed-users FAILED:', err.message)
  process.exit(1)
})

