// One-off: push the MOST RECENT member_goal_plans row's start_date to tomorrow
// (end_date = start + 6). Keys come from admin/.env — never hardcoded.
// Run: node scripts/set-plan-start-tomorrow.mjs   (from admin/)
import { config } from 'dotenv'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
import { createClient } from '@supabase/supabase-js'

config({ path: resolve(dirname(fileURLToPath(import.meta.url)), '..', '.env') })

const url = process.env.VITE_SUPABASE_URL ?? process.env.SUPABASE_URL
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY
if (!url || !serviceKey) {
  console.error('Missing VITE_SUPABASE_URL (or SUPABASE_URL) or SUPABASE_SERVICE_ROLE_KEY in admin/.env')
  process.exit(1)
}
const db = createClient(url, serviceKey)

const { data: plans, error } = await db
  .from('member_goal_plans')
  .select('id, member_id, start_date, end_date')
  .order('created_at', { ascending: false })
  .limit(1)
if (error) throw error
if (!plans || plans.length === 0) {
  console.log('No plans found — nothing to update.')
  process.exit(0)
}

const plan = plans[0]
const pad = (n) => String(n).padStart(2, '0')
const start = new Date()
start.setDate(start.getDate() + 1)
const end = new Date(start)
end.setDate(end.getDate() + 6)
const startStr = `${start.getFullYear()}-${pad(start.getMonth() + 1)}-${pad(start.getDate())}`
const endStr = `${end.getFullYear()}-${pad(end.getMonth() + 1)}-${pad(end.getDate())}`

const { error: upErr } = await db
  .from('member_goal_plans')
  .update({ start_date: startStr, end_date: endStr, updated_at: new Date().toISOString() })
  .eq('id', plan.id)
if (upErr) throw upErr

console.log(
  `Updated plan ${plan.id} (member ${plan.member_id}): ` +
    `${plan.start_date} -> ${startStr}, ${plan.end_date} -> ${endStr}`,
)
