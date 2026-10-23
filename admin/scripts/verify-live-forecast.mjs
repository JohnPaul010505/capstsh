import { config } from 'dotenv'
import { createClient } from '@supabase/supabase-js'
import assert from 'node:assert/strict'
config({ quiet: true })
const db = createClient(process.env.VITE_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY)
const { data: member, error } = await db.from('profiles').select('id').eq('code', '2023-01-M002').single()
if (error) throw error
const since = new Date().toISOString()
const response = await fetch('http://127.0.0.1:3001/api/ai/predictions', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ member_id: member.id, days_ahead: 30 }) })
assert.equal(response.status, 200)
assert.equal(response.headers.get('x-forecast-source'), 'ai', 'Proxy must reach forecast service rather than offline fallback')
const results = await response.json()
assert.ok(results.some(result => result.sufficient !== false))
assert.ok(results.every(result => Number.isFinite(result.predicted_value)))
const { data: saved, error: savedError } = await db.from('predictions').select('metric_name, predicted_value').eq('member_id', member.id).gte('created_at', since)
if (savedError) throw savedError
assert.ok(saved.length > 0, 'Forecast must be saved to history')
console.log('PASS live forecast: admin proxy reached service, returned finite results, and saved history', { results: results.length, saved: saved.length })
