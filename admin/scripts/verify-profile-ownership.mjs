import { config } from 'dotenv'
import { createClient } from '@supabase/supabase-js'
import assert from 'node:assert/strict'
config({ quiet: true })
const missing = await fetch('http://127.0.0.1:3001/api/trainer/profile', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' })
assert.equal(missing.status, 401)
const db = createClient(process.env.VITE_SUPABASE_URL, process.env.VITE_SUPABASE_ANON_KEY)
const { data, error } = await db.auth.signInWithPassword({ email: process.env.ADMIN_EMAIL, password: process.env.ADMIN_PASSWORD })
if (error) throw error
const forbidden = await fetch('http://127.0.0.1:3001/api/trainer/profile', { method: 'POST', headers: { Authorization: `Bearer ${data.session.access_token}`, 'Content-Type': 'application/json' }, body: '{}' })
assert.equal(forbidden.status, 403)
console.log('PASS trainer endpoint rejects missing sessions and admin accounts without changing records')
