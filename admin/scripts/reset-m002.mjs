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

// Member-owned tables filtered by the M002 user id. chat_rooms is wiped last
// so the FK cascade on chat_messages.room_id cleans up remaining messages.
const MEMBER_TABLE_FILTERS = [
  ['workout_logs', 'member_id'],
  ['body_measurements', 'member_id'],
  ['attendance', 'member_id'],
  ['goals', 'member_id'],
  ['trainer_feedback', 'member_id'],
  ['meal_records', 'member_id'],
  ['food_recommendations', 'member_id'],
  ['predictions', 'member_id'],
  ['notifications', 'user_id'],
  ['chat_messages', 'sender_id'],
]

async function main() {
  const { data: profile, error: profileError } = await client
    .from('profiles')
    .select('id, full_name, code, gender')
    .eq('code', 'M002')
    .maybeSingle()
  if (profileError) throw profileError
  if (!profile) {
    console.error('M002 not found in profiles — aborting')
    process.exit(1)
  }
  const memberId = profile.id
  console.log(`Resetting M002 (${profile.full_name}, ${profile.id})...`)

  const counts = []
  for (const [table, column] of MEMBER_TABLE_FILTERS) {
    const { count, error } = await client
      .from(table)
      .delete()
      .eq(column, memberId)
      .select('id', { count: 'exact', head: false })
    if (error) throw new Error(`${table}: ${error.message}`)
    counts.push([table, count ?? 0])
  }

  // Chat rooms where M002 is a participant (cascades leftover messages).
  const { count: roomCount, error: roomError } = await client
    .from('chat_rooms')
    .delete()
    .or(`participant_one.eq.${memberId},participant_two.eq.${memberId}`)
    .select('id', { count: 'exact', head: false })
  if (roomError) throw new Error(`chat_rooms: ${roomError.message}`)

  const { error: genderError } = await client
    .from('profiles')
    .update({ gender: null })
    .eq('id', memberId)
  if (genderError) throw new Error(`profiles gender clear: ${genderError.message}`)

  for (const [table, n] of counts) console.log(`  ${table}: deleted ${n}`)
  console.log(`  chat_rooms: deleted ${roomCount ?? 0}`)
  console.log('  profiles: gender cleared (kept account, membership, trainer assignment)')

  console.log('M002 reset complete. It now looks like a brand-new member (gender empty, no measurements).')
  console.log('Restore demo data later with: npm run seed:m002')
}

main().catch((e) => {
  console.error('Reset failed:', e)
  process.exit(1)
})
