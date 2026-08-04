import { config } from 'dotenv'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
config({ path: resolve(dirname(fileURLToPath(import.meta.url)), '..', '.env') })
import { createClient } from '@supabase/supabase-js'

const client = createClient(process.env.VITE_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

const probeSelect = async (table, col) => {
  try {
    await client.from(table).select(col).limit(1)
    return `select ${col} OK`
  } catch (e) {
    return `select ${col} FAIL: ${e.message}`
  }
}

const probeInsert = async (table, payload) => {
  const { error } = await client.from(table).insert(payload)
  if (!error) return 'insert unexpectedly succeeded'
  if (error.code === '23503') return `insert OK (FK error = column accepted): ${error.message.split('\n')[0]}`
  if (error.code === 'PGRST204') return `insert FAIL: ${error.message}`
  return `insert OTHER ${error.code}: ${error.message.split('\n')[0]}`
}

const fake = '00000000-0000-0000-0000-000000000000'
console.log(await probeSelect('profiles', 'is_active'))
console.log(await probeSelect('attendance', 'expires_at'))
console.log(await probeInsert('profiles', { id: fake, role: 'member', full_name: 'Probe', email: 'probe@probe.fit', is_active: true }))
console.log(await probeInsert('attendance', { member_id: fake, check_in_date: '2026-01-05', expires_at: new Date().toISOString() }))
console.log(await probeInsert('workout_logs', { member_id: fake, exercise_name: 'Probe', weight_kg: 60, proof_type: 'video' }))
