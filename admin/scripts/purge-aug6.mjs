import { config } from 'dotenv'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
config({ path: resolve(dirname(fileURLToPath(import.meta.url)), '..', '.env') })
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.VITE_SUPABASE_URL
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY
if (!supabaseUrl || !serviceRoleKey) {
  console.error('Missing VITE_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in admin/.env')
  process.exit(1)
}
const client = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
})

const AUG6_START = '2026-08-06T00:00:00+08:00'
const AUG6_END = '2026-08-07T00:00:00+08:00'

const AUG6_TABLE_FILTERS = [
  ['workout_logs', 'member_id', 'logged_at'],
  ['body_measurements', 'member_id', 'measured_at'],
  ['attendance', 'member_id', 'check_in_date', '2026-08-06'],
  ['meal_records', 'member_id', 'recorded_at'],
]

async function main() {
  const { data: profile } = await client
    .from('profiles')
    .select('id, full_name, code')
    .eq('code', 'M002')
    .maybeSingle()
  if (!profile) {
    console.error('M002 not found')
    process.exit(1)
  }
  const memberId = profile.id
  console.log('Purging Aug 6 data for M002 (' + profile.full_name + ', ' + memberId + ')...')

  const counts = []
  for (const [table, column, dateCol, ...rest] of AUG6_TABLE_FILTERS) {
    const exactDate = rest[0]
    let query = client.from(table).delete().eq(column, memberId)
    if (exactDate) {
      query = query.eq(dateCol, exactDate)
    } else {
      query = query.gte(dateCol, AUG6_START).lt(dateCol, AUG6_END)
    }
    const { count, error } = await query.select('id', { count: 'exact', head: false })
    if (error) throw new Error(table + ': ' + error.message)
    counts.push([table, count ?? 0])
  }

  for (const [table, n] of counts) console.log('  ' + table + ': deleted ' + n)
  console.log('M002 Aug 6 purge complete. All other dates remain intact.')
}
main().catch((e) => {
  console.error('Purge failed:', e)
  process.exit(1)
})