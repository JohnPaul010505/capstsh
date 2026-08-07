// Dedupe workout_logs: keep only the earliest row per (member_id, exercise_name, logged_at).
// Run with: node scripts/dedupe-workout-logs.mjs
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

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
})

async function fetchAllRows() {
  const all = []
  let from = 0
  const pageSize = 1000
  for (;;) {
    const { data, error } = await admin
      .from('workout_logs')
      .select('id, member_id, exercise_name, logged_at')
      .order('logged_at', { ascending: true })
      .range(from, from + pageSize - 1)
    if (error) throw error
    if (!data || data.length === 0) break
    all.push(...data)
    if (data.length < pageSize) break
    from += pageSize
  }
  return all
}

async function main() {
  const logs = await fetchAllRows()
  console.log(`Total rows before: ${logs.length}`)

  const groups = new Map()
  for (const row of logs) {
    const key = `${row.member_id}|${row.exercise_name}|${row.logged_at}`
    if (!groups.has(key)) groups.set(key, [])
    groups.get(key).push(row)
  }

  const dupes = []
  let kept = 0
  for (const [key, rows] of groups) {
    rows.sort((a, b) => (a.id < b.id ? -1 : 1))
    kept++
    for (const r of rows.slice(1)) dupes.push(r.id)
  }

  console.log(`Unique (kept): ${kept}`)
  console.log(`Duplicates to delete: ${dupes.length}`)

  if (dupes.length === 0) {
    console.log('Nothing to delete.')
    return
  }

  // Delete in batches of 1000 (URL length limit).
  for (let i = 0; i < dupes.length; i += 1000) {
    const batch = dupes.slice(i, i + 1000)
    const { error: delError } = await admin.from('workout_logs').delete().in('id', batch)
    if (delError) throw delError
    console.log(`Deleted batch ${i + 1}-${i + batch.length}`)
  }

  const { count, error: countError } = await admin
    .from('workout_logs')
    .select('*', { count: 'exact', head: true })
  if (countError) throw countError
  console.log(`Total rows after: ${count}`)
}

main().catch((e) => {
  console.error('Failed:', e.message)
  process.exit(1)
})
