import { config } from 'dotenv'
import { createClient } from '@supabase/supabase-js'
import { randomUUID } from 'node:crypto'
import assert from 'node:assert/strict'

config({ quiet: true })
const options = { auth: { persistSession: false, autoRefreshToken: false } }
const admin = createClient(process.env.VITE_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, options)
const ids = []
const check = ({ data, error }) => { if (error) throw error; return data }
async function account(role) {
  const email = `profile-check-${randomUUID()}@example.invalid`
  const password = `Test-${randomUUID()}!`
  const { user } = check(await admin.auth.admin.createUser({ email, password, email_confirm: true }))
  ids.push(user.id)
  check(await admin.from('profiles').upsert({ id: user.id, role, full_name: `Profile verification ${role}`, email }))
  const client = createClient(process.env.VITE_SUPABASE_URL, process.env.VITE_SUPABASE_ANON_KEY, options)
  check(await client.auth.signInWithPassword({ email, password }))
  return { id: user.id, client }
}
try {
  const trainer = await account('trainer')
  const member = await account('member')
  check(await admin.from('trainer_assignments').insert({ trainer_id: trainer.id, member_id: member.id, status: 'active' }))
  const schedule = 'Mon 09:00-12:00,Tue 12:00-16:00,Wed 15:00-18:00'
  const saved = check(await trainer.client.from('profiles').update({ specialty: 'Strength', available_days: schedule, phone: '09000000000' }).eq('id', trainer.id).select().single())
  assert.equal(saved.available_days, schedule)
  const reread = check(await member.client.from('profiles').select('available_days,specialty').eq('id', trainer.id).single())
  assert.equal(reread.available_days, schedule)
  check(await trainer.client.from('notifications').insert({ user_id: member.id, title: 'Trainer details updated', sender_name: saved.full_name, body: `Specialty: ${saved.specialty}. Availability: ${saved.available_days}.` }))
  const notifications = check(await member.client.from('notifications').select('body').eq('user_id', member.id).eq('title', 'Trainer details updated'))
  assert.ok(notifications.some(row => row.body.includes(schedule)))
  check(await member.client.from('profiles').update({ address: 'Profile save verification' }).eq('id', member.id).select('id').single())
  const seen = check(await trainer.client.from('profiles').select('address').eq('id', member.id).single())
  assert.equal(seen.address, 'Profile save verification')
  const forbidden = await trainer.client.from('profiles').update({ address: 'Forbidden edit' }).eq('id', member.id).select('id')
  assert.ok(forbidden.error || forbidden.data.length === 0)
  console.log('PASS: authenticated trainer and member saves, persisted schedule read by member, assignment notification, member details read by trainer, and cross-user edit rejection.')
} finally {
  for (const id of ids.reverse()) check(await admin.auth.admin.deleteUser(id))
  console.log('Temporary verification accounts and their related records removed.')
}
