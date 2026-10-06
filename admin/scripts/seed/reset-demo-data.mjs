// Purge every GENERATED demo row so the seed can rebuild one even
// 2023-01-01..today dataset (Task 3 of the 2026-09-28 dataset plan).
//
// Safety model - the script can only ever remove rows it created:
//   * every table is matched on its own 3e01a0xx seed id prefix, never on a
//     date range and never on a row count;
//   * `profiles` is never listed. Profiles are re-anchored in place by
//     reanchorJoinedAt(), so the Mxxx / Txxx codes keep their meaning;
//   * hand-written showcase rows (1c01e0ac..., 3e01a001, 3e01a002) carry
//     other prefixes and are therefore out of reach.
//
// Why a text RANGE and not `like`: every id is a `uuid` column, and Postgres
// has no `uuid ~~ text` operator, so PostgREST answers
// `42883 No operator matches the given name and argument types` for
// `id=like.3e01a003*`. Casting works for ordered comparison
// (`id::text=gte.`) but NOT for `like`, and a failed `like` returns no count
// and no error - it just looks like "0 seed rows". The seed ids are
// deterministic (`uuid(prefix, n)` => prefix-0000-4000-8000-<12 hex>), so the
// exact inclusive id range below is both safe and complete.
//
// Usage (non-interactive, so a destructive run must be asked for explicitly):
//   node scripts/seed/reset-demo-data.mjs --dry-run   count only, deletes nothing
//   node scripts/seed/reset-demo-data.mjs --confirm   delete the seed rows
import { client } from './lib/common.mjs'
import { ATT_ID_PREFIX } from './lib/attendance.mjs'
import { MEMBERSHIP_ID_PREFIX } from './lib/memberships.mjs'
import { ASSIGNMENT_ID_PREFIX, FEEDBACK_ID_PREFIX } from './lib/coaching.mjs'
import { PREDICTION_ID_PREFIX } from './lib/predictions.mjs'
import { RENEWAL_ID_PREFIX, NOTIFICATION_ID_PREFIX, RENEWAL_NOTICE_TITLE } from './lib/renewals.mjs'
import { ENROLLMENT_ID_PREFIX } from './lib/enrollments.mjs'

// Children before parents: trainer_feedback has an FK onto
// trainer_assignments, so it must go first. Every other table only points at
// profiles, which this script never deletes.
const TABLES = [
  { table: 'trainer_feedback', prefix: FEEDBACK_ID_PREFIX, note: 'FK -> trainer_assignments' },
  { table: 'trainer_assignments', prefix: ASSIGNMENT_ID_PREFIX, note: 'FK -> profiles' },
  { table: 'membership_renewal_requests', prefix: RENEWAL_ID_PREFIX, note: 'FK -> profiles' },
  { table: 'notifications', prefix: NOTIFICATION_ID_PREFIX, note: 'FK -> profiles' },
  { table: 'predictions', prefix: PREDICTION_ID_PREFIX, note: 'FK -> profiles' },
  { table: 'attendance', prefix: ATT_ID_PREFIX, note: 'FK -> profiles' },
  { table: 'memberships', prefix: MEMBERSHIP_ID_PREFIX, note: 'FK -> profiles' },
  { table: 'enrollments', prefix: ENROLLMENT_ID_PREFIX, note: 'FK -> profiles (confirmed_by)' },
]

// Rows the DATABASE creates, which no id prefix can reach.
//
// Migration 0027's AFTER INSERT trigger writes one RENEWAL_NOTICE_TITLE
// notification per admin for every renewal row, using a database-generated uuid.
// Those ids sit outside every 3e01a0xx seed range, so a purge leaves them
// behind and the next seeding run creates another full batch: after two
// re-seeds the table held 420 rows with this title (2 x RENEWAL_TARGET 210) out
// of 1,051 total, 56 of them exact (user_id, title, created_at) duplicates
// inside the newest page the Notifications screen reads. A purge has to name
// those rows by what they ARE, not by who inserted them.
//
// The seed never inserts this title itself - buildNotifications() models them
// for realism, counts them separately and filters them out as `_auto` - so every
// row carrying the title came from the trigger. That is asserted below rather
// than assumed: the delete is refused if any of them turns out to be reachable
// by the seed range instead.
const TRIGGER_OWNED = [
  { table: 'notifications', title: RENEWAL_NOTICE_TITLE, owner: 'migration 0027 notify_membership_renewal' },
]


/** Tables this script must never write to, whatever the arguments say. */
const PROTECTED = ['profiles', 'goals', 'workout_logs', 'meal_logs', 'body_measurements']

const PREFIX_RE = /^3e01a0[0-9a-f]{2}$/

for (const t of TABLES) {
  if (!PREFIX_RE.test(t.prefix)) {
    throw new Error(`refusing to run: ${t.table} prefix "${t.prefix}" is not a 3e01a0xx seed prefix`)
  }
  if (PROTECTED.includes(t.table)) {
    throw new Error(`refusing to run: ${t.table} is on the protected list`)
  }
}

for (const t of TRIGGER_OWNED) {
  const owner = TABLES.find((x) => x.table === t.table)
  if (!owner) {
    throw new Error(`refusing to run: trigger-owned table ${t.table} is not in TABLES, so its id range is unknown`)
  }
  if (PROTECTED.includes(t.table)) {
    throw new Error(`refusing to run: ${t.table} is on the protected list`)
  }
  if (!t.title) {
    throw new Error(`refusing to run: trigger-owned ${t.table} has no title to match on`)
  }
}


const args = process.argv.slice(2)
const dryRun = args.includes('--dry-run')
const confirmed = args.includes('--confirm')

if (!dryRun && !confirmed) {
  console.error('Refusing to delete without an explicit flag.')
  console.error('  --dry-run   count the seed rows and delete nothing')
  console.error('  --confirm   delete them (profiles are never touched)')
  process.exit(1)
}

/** Exact inclusive id range owned by one seed prefix. */
const idBounds = (prefix) => [
  `${prefix}-0000-4000-8000-000000000000`,
  `${prefix}-0000-4000-8000-ffffffffffff`,
]

/** Restrict any PostgREST query (select or delete) to one seed prefix. */
const onlyPrefix = (q, prefix) => {
  const [lo, hi] = idBounds(prefix)
  return q.filter('id::text', 'gte', lo).filter('id::text', 'lte', hi)
}

const countAll = async (table) => {
  const { count, error } = await client.from(table).select('*', { count: 'exact', head: true })
  if (error) throw new Error(`${table} count failed: ${error.message}`)
  return count ?? 0
}

const countSeed = async (table, prefix) => {
  const { count, error } = await onlyPrefix(
    client.from(table).select('id', { count: 'exact', head: true }),
    prefix,
  )
  if (error) throw new Error(`${table} seed count failed: ${error.message}`)
  if (count === null) {
    throw new Error(`${table} returned no count for prefix ${prefix} - refusing to continue`)
  }
  return count
}


/**
 * Count the rows a trigger owns, and how many of them the seed's own id range
 * could have reached.
 *
 * `reachable` is the safety interlock. The title match is only correct while
 * the seed never inserts that title itself; if it ever did, those rows would be
 * deleted by the prefix pass instead, and this one must refuse rather than
 * double-count them.
 */
const countTriggerOwned = async ({ table, title }) => {
  const owner = TABLES.find((t) => t.table === table)
  if (!owner) throw new Error(`${table} is not in TABLES, so its id range is unknown`)

  const { count, error } = await client
    .from(table).select('id', { count: 'exact', head: true })
    .eq('title', title)
  if (error) throw new Error(`${table} title count failed: ${error.message}`)
  if (count === null) throw new Error(`${table} returned no count for title "${title}" - refusing to continue`)

  const { count: reachable, error: rErr } = await onlyPrefix(
    client.from(table).select('id', { count: 'exact', head: true }).eq('title', title),
    owner.prefix,
  )
  if (rErr) throw new Error(`${table} title+prefix count failed: ${rErr.message}`)

  return { total: count, reachable: reachable ?? 0 }
}

async function main() {
  console.log(`=== RESET DEMO DATA (${dryRun ? 'DRY RUN - nothing will be deleted' : 'LIVE'}) ===`)

  const profilesBefore = await countAll('profiles')
  const seen = new Set()
  const plan = []
  for (const t of TABLES) {
    if (seen.has(t.table)) throw new Error(`duplicate table in plan: ${t.table}`)
    seen.add(t.table)
    const seedRows = await countSeed(t.table, t.prefix)
    const total = await countAll(t.table)
    plan.push({ ...t, seedRows, total, kept: total - seedRows })
  }

  console.table(
    plan.map((p) => ({
      table: p.table,
      seed_prefix: p.prefix,
      'seed rows': p.seedRows,
      'other rows (kept)': p.kept,
      'table total': p.total,
      order_note: p.note,
    })),
  )

  const seedTotal = plan.reduce((n, p) => n + p.seedRows, 0)
  const keptTotal = plan.reduce((n, p) => n + p.kept, 0)
  console.log(`Seed rows matched: ${seedTotal}   other rows kept: ${keptTotal}`)
  console.log(`Profiles before: ${profilesBefore} (never modified by this script)`)

  // The trigger's rows are counted separately because they are matched by title
  // rather than by id: their uuids are database-generated, so the id-range purge
  // above reported them as "other rows (kept)" even though a re-seed recreates
  // them. They are NOT protected rows - they are the residue of a previous run.
  const triggerPlan = []
  for (const t of TRIGGER_OWNED) {
    const { total, reachable } = await countTriggerOwned(t)
    if (reachable > 0) {
      throw new Error(
        `refusing to delete ${t.table} "${t.title}": ${reachable} of ${total} matching rows sit INSIDE the seed ` +
        `id range, so the seed - not ${t.owner} - created them. Widen the title match before purging.`,
      )
    }
    triggerPlan.push({ ...t, triggerRows: total })
  }

  if (triggerPlan.length) {
    console.table(
      triggerPlan.map((t) => ({
        table: t.table,
        matched_by: `title = "${t.title}"`,
        'trigger rows': t.triggerRows,
        inside_seed_range: 0,
        created_by: t.owner,
      })),
    )
    const triggerTotal = triggerPlan.reduce((n, t) => n + t.triggerRows, 0)
    console.log(
      `Trigger-owned rows matched: ${triggerTotal} - counted in "other rows (kept)" above, but purged here ` +
      'because a re-seed would otherwise create a second batch of the same rows.',
    )
  }


  if (dryRun) {
    console.log('\nDRY RUN: no rows deleted. Re-run with --confirm to purge.')
    return
  }

  for (const p of plan) {
    if (!p.seedRows) {
      console.log(`  ${p.table}: nothing to delete`)
      continue
    }
    const { error } = await onlyPrefix(client.from(p.table).delete(), p.prefix)
    if (error) throw new Error(`${p.table} delete failed: ${error.message}`)
    const after = await countSeed(p.table, p.prefix)
    if (after !== 0) throw new Error(`${p.table}: ${after} seed rows survived the delete`)
    console.log(`  ${p.table}: deleted ${p.seedRows}`)
  }


  // Trigger-owned rows go last, and by title rather than by id: they carry
  // database-generated uuids, so this is the only way to reach them.
  for (const t of triggerPlan) {
    if (!t.triggerRows) {
      console.log(`  ${t.table} "${t.title}": nothing to delete`)
      continue
    }
    const { error } = await client.from(t.table).delete().eq('title', t.title)
    if (error) throw new Error(`${t.table} trigger-row delete failed: ${error.message}`)
    const after = await countTriggerOwned(t)
    if (after.total !== 0) {
      throw new Error(`${t.table}: ${after.total} "${t.title}" rows survived the delete`)
    }
    console.log(`  ${t.table}: deleted ${t.triggerRows} "${t.title}" rows (created by ${t.owner})`)
  }

  const profilesAfter = await countAll('profiles')
  if (profilesAfter !== profilesBefore) {
    throw new Error(`profiles changed (${profilesBefore} -> ${profilesAfter}) - investigate before re-seeding`)
  }
  console.log(`\nDone. Seed rows are gone, profiles still ${profilesAfter}. Safe to re-run the seed.`)
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
