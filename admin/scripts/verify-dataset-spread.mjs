// Verify the SEEDED demo dataset really covers DATA_START..today and is evenly
// spread - read from the DATABASE, not the generator, so a stale cache or a
// half-finished re-seed cannot pass it.
//
// What it checks:
//   1. `DATA_START` in the seed library and in the admin app agree (drift guard).
//   2. No attendance / membership row before DATA_START.
//   3. No attendance after today (no "future" check-ins on screenshots).
//   4. Every month in the window has attendance rows (no holes in the charts).
//   5. Monthly volume stays within a tolerance of the median (flat-ish).
//   6. No Sunday sessions (the gym is closed), matching the generator.
//   7. `member_last_checkin` returns every distinct member, not a truncated page.
//
// Usage: node scripts/verify-dataset-spread.mjs
import { readFileSync } from 'node:fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
import { client, DATA_START } from './seed/lib/common.mjs'
import { ATT_ID_PREFIX } from './seed/lib/attendance.mjs'

const __dirname = dirname(fileURLToPath(import.meta.url))
const APP_RANGE_PATH = resolve(__dirname, '..', 'src', 'features', 'dashboard', 'lib', 'dateRange.ts')
const PAGE = 1000

let failures = 0
const check = (ok, label, detail = '') => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  (${detail})` : ''}`)
  if (!ok) failures++
}

const localDate = (d) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

/** Paged read - PostgREST truncates an unbounded select at 1,000 rows. */
async function pageAll(build) {
  const out = []
  for (let from = 0; ; from += PAGE) {
    const { data, error } = await build(from, from + PAGE - 1)
    if (error) throw new Error(error.message)
    out.push(...(data ?? []))
    if (!data || data.length < PAGE) return out
  }
}

function monthKeys(fromIso, toIso) {
  const out = []
  const [fy, fm] = fromIso.split('-').map(Number)
  const [ty, tm] = toIso.split('-').map(Number)
  for (let y = fy, m = fm; y < ty || (y === ty && m <= tm); m === 12 ? ((y++), (m = 1)) : m++) {
    out.push(`${y}-${String(m).padStart(2, '0')}`)
  }
  return out
}

async function main() {
  console.log('=== VERIFY DATASET SPREAD ===')
  console.log(`seed DATA_START: ${DATA_START}\n`)

  // 1. drift guard: the app's copy of DATA_START must match the seed's.
  const appSource = readFileSync(APP_RANGE_PATH, 'utf8')
  const appMatch = /export const DATA_START = '(\d{4}-\d{2}-\d{2})'/.exec(appSource)
  check(!!appMatch && appMatch[1] === DATA_START, 'app and seed DATA_START agree',
    appMatch ? `app=${appMatch[1]} seed=${DATA_START}` : 'DATA_START not found in dateRange.ts')

  const today = localDate(new Date())
  const seedFilter = (q) =>
    q.filter('id::text', 'gte', `${ATT_ID_PREFIX}-0000-4000-8000-000000000000`)
     .filter('id::text', 'lte', `${ATT_ID_PREFIX}-0000-4000-8000-ffffffffffff`)

  // Read only SEEDED attendance, so a leftover showcase row cannot skew counts.
  const rows = await pageAll((from, to) =>
    seedFilter(client.from('attendance').select('check_in_date'))
      .order('check_in_date', { ascending: true })
      .range(from, to))

  check(rows.length > 0, 'seeded attendance present', `${rows.length} rows`)
  if (!rows.length) return finish()

  const first = rows[0].check_in_date
  const last = rows[rows.length - 1].check_in_date
  console.log(`range: ${first} → ${last}\n`)

  // 2. no rows before the window
  check(first >= DATA_START, 'no attendance before DATA_START', `earliest ${first}`)

  // 3. no future check-ins
  check(last <= today, 'no attendance after today', `latest ${last}`)

  // 4. every month covered
  const byMonth = new Map()
  for (const r of rows) byMonth.set(r.check_in_date.slice(0, 7), (byMonth.get(r.check_in_date.slice(0, 7)) ?? 0) + 1)
  const expected = monthKeys(DATA_START, today)
  const missing = expected.filter((m) => !byMonth.has(m))
  check(missing.length === 0, 'every month has attendance', missing.length ? `missing ${missing.join(', ')}` : `${expected.length} months`)

  // 5. flat base volume.
  //    The regular-attender overlay is DELIBERATELY concentrated: the three
  //    current tiers cover the last OVERLAY_WEEKS (12) weeks and the churned
  //    tier covers weeks 26-38 back, because ai-service/services/ml.py buckets
  //    the most recent check-ins to score retention. Those two windows are
  //    therefore expected to sit well above the base, and they are what the
  //    `predictions` table is built from. Flatness is asserted over the BASE
  //    region only - the months outside both overlay windows - which is the part
  //    that actually fills the "All time" charts.
  const OVERLAY_REACH_DAYS = 40 * 7 // 12 weeks forward, churned reaches 38 weeks back
  const baseCutoff = new Date(`${today}T00:00:00`)
  baseCutoff.setDate(baseCutoff.getDate() - OVERLAY_REACH_DAYS)
  const isBase = (m) => new Date(`${m}-01T00:00:00`) < baseCutoff && m !== today.slice(0, 7)
  const baseVols = expected.filter(isBase).map((m) => byMonth.get(m) ?? 0)
  const sorted = [...baseVols].sort((a, b) => a - b)
  const median = sorted[Math.floor(sorted.length / 2)]
  const outliers = expected.filter((m) => isBase(m) && (byMonth.get(m) ?? 0) < median * 0.7)
  check(outliers.length === 0, 'base monthly volume is flat',
    `median ${median}/mo over ${baseVols.length} base months, outliers ${outliers.length ? outliers.join(', ') : 'none'}`)

  // The overlay windows are bounded but not flat; report them rather than fail.
  const overlayMonths = expected.filter((m) => !isBase(m))
  console.log(`      overlay window(s) ${overlayMonths[0]}..${overlayMonths[overlayMonths.length - 1]}: ` +
    `${overlayMonths.map((m) => byMonth.get(m) ?? 0).join('/')} rows (expected to exceed the base)`)

  // 6. no Sunday sessions
  const sundays = rows.filter((r) => new Date(`${r.check_in_date}T00:00:00`).getDay() === 0)
  check(sundays.length === 0, 'no Sunday sessions', `${sundays.length} found`)

  // 7. the aggregate returns every distinct member.
  //    Called with EXPLICIT named args: migration 0036 added a defaulted
  //    (p_limit, p_offset) overload beside 0035's zero-argument function, so a
  //    no-argument call is ambiguous until migration 0037 drops the old one.
  //    This mirrors exactly what the dashboard does.
  const { data: countRow, error: cntErr } = await client.rpc('member_last_checkin_count')
  if (cntErr) {
    check(false, 'member_last_checkin_count RPC responds', cntErr.message)
  } else {
    const total = Number(countRow)
    const seen = new Set()
    for (let offset = 0; offset < total; offset += PAGE) {
      const { data, error } = await client.rpc('member_last_checkin', { p_limit: PAGE, p_offset: offset })
      if (error) {
        check(false, 'member_last_checkin RPC responds', error.message)
        break
      }
      for (const r of data ?? []) seen.add(r.member_id)
    }
    check(seen.size === total, 'member_last_checkin returns every member', `${seen.size} of ${total}`)
  }

  finish()
}

function finish() {
  console.log(failures === 0 ? '\nDATASET SPREAD OK' : `\n${failures} CHECK(S) FAILED`)
  process.exit(failures === 0 ? 0 : 2)
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})

