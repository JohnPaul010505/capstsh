import { config } from 'dotenv'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
config({ path: resolve(dirname(fileURLToPath(import.meta.url)), '..', '.env') })
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.VITE_SUPABASE_URL
const anonKey = process.env.VITE_SUPABASE_ANON_KEY
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY

const service = createClient(supabaseUrl, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } })
const today = new Date().toISOString().split('T')[0]

// Pick a seeded member with NO attendance today (so demo state is untouched)
const { data: todaysRows } = await service.from('attendance').select('member_id').eq('check_in_date', today)
const busy = new Set((todaysRows ?? []).map((r) => r.member_id))
const { data: members } = await service.from('profiles').select('id,email').eq('role', 'member').eq('email', 'member9@mock.fit')
let member = members?.find((m) => !busy.has(m.id))
if (!member) {
  console.log('member9 busy today; trying others')
  const { data: all } = await service.from('profiles').select('id,email').eq('role', 'member')
  member = all.find((m) => m.email.endsWith('@mock.fit') && !busy.has(m.id))
}
if (!member) { console.log('no free member'); process.exit(1) }
console.log(`test member: ${member.email}`)

// 1. Member check-in / check-out cycle with anon (RLS) client
const memberClient = createClient(supabaseUrl, anonKey, { auth: { autoRefreshToken: false, persistSession: false } })
const { error: signInErr } = await memberClient.auth.signInWithPassword({ email: member.email, password: 'MockPass123!' })
if (signInErr) { console.log('SIGNIN FAIL', signInErr.message); process.exit(1) }
console.log('member signed in OK')

const now = new Date().toISOString()
const { data: user } = await memberClient.auth.getUser()
const memberId = user.user.id

const { data: insRow, error: insErr } = await memberClient.from('attendance').insert({
  member_id: memberId, check_in_time: now, check_in_date: today,
  expires_at: new Date(Date.now() + 12 * 3600000).toISOString(),
}).select('id').single()
if (insErr) { console.log('CHECKIN FAIL', insErr.code, insErr.message); process.exit(1) }
console.log('member check-in insert OK (RLS), id:', insRow.id)

const { data: openRows, error: selErr } = await memberClient
  .from('attendance').select('id')
  .eq('member_id', memberId).eq('check_in_date', today).is('check_out_time', null)
if (selErr) { console.log('SELECT FAIL', selErr.message); process.exit(1) }
console.log(`open sessions found: ${openRows.length}`)

const { error: updErr } = await memberClient
  .from('attendance').update({ check_out_time: now })
  .eq('member_id', memberId).eq('check_in_date', today).is('check_out_time', null)
if (updErr) { console.log('CHECKOUT FAIL', updErr.code, updErr.message); process.exit(1) }
console.log('member check-out update OK (RLS)')

// 2. Trainer reads assigned member attendance (RLS)
const trainerClient = createClient(supabaseUrl, anonKey, { auth: { autoRefreshToken: false, persistSession: false } })
const { error: tErr } = await trainerClient.auth.signInWithPassword({ email: 'trainer1@mock.fit', password: 'MockPass123!' })
if (tErr) { console.log('TRAINER SIGNIN FAIL', tErr.message); process.exit(1) }
const { data: tAtt, error: tAttErr } = await trainerClient
  .from('attendance').select('member_id').eq('member_id', memberId).limit(1)
console.log(tAttErr ? `TRAINER READ FAIL: ${tAttErr.message}` : `trainer reads assigned member attendance OK (${tAtt.length} row)`)

// 3. Cleanup: delete the test row by exact id
const { error: delErr } = await service.from('attendance').delete().eq('id', insRow.id)
console.log(delErr ? `CLEANUP FAIL: ${delErr.message}` : 'cleanup OK')
