import { config } from 'dotenv'
import { createClient } from '@supabase/supabase-js'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

config({ path: resolve(dirname(fileURLToPath(import.meta.url)), '..', '.env') })

const supabaseUrl = process.env.VITE_SUPABASE_URL
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY
if (!supabaseUrl || !serviceRoleKey) {
  console.error('Missing Supabase configuration in admin/.env')
  process.exit(1)
}

const client = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
})

const dateOnly = (date) =>
  `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`

async function main() {
  const { data: profile, error: profileError } = await client
    .from('profiles')
    .select('id, full_name')
    .eq('code', '2023-01-M002')
    .maybeSingle()
  if (profileError) throw profileError
  if (!profile) throw new Error('Member 2023-01-M002 was not found.')

  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const yearStart = new Date(today.getFullYear(), 0, 1)
  const tomorrow = new Date(today.getTime() + 24 * 60 * 60 * 1000)
  const { data: saved, error: savedError } = await client
    .from('attendance')
    .select('check_in_date')
    .eq('member_id', profile.id)
    .gte('check_in_date', dateOnly(yearStart))
    .lt('check_in_date', dateOnly(tomorrow))
  if (savedError) throw savedError

  const existingDates = new Set((saved ?? []).map((row) => row.check_in_date))
  const sessions = []
  for (const day = new Date(yearStart); day < today; day.setDate(day.getDate() + 1)) {
    // Three predictable gym days per week, evenly spaced, through yesterday.
    if (![1, 3, 5].includes(day.getDay())) continue // Mon, Wed, Fri
    const checkInDate = dateOnly(day)
    if (existingDates.has(checkInDate)) continue

    // Stable date-derived UUID makes reruns idempotent without touching the
    // member's real attendance rows or any other member's records.
    const compactDate = checkInDate.replaceAll('-', '')
    const checkIn = new Date(day)
    checkIn.setHours(18, 0, 0, 0)
    const checkOut = new Date(checkIn.getTime() + 90 * 60 * 1000)
    sessions.push({
      id: `9c01e0b0-0000-4000-8000-${compactDate}0000`,
      member_id: profile.id,
      check_in_time: checkIn.toISOString(),
      check_in_date: checkInDate,
      check_out_time: checkOut.toISOString(),
      expires_at: new Date(checkIn.getTime() + 12 * 60 * 60 * 1000).toISOString(),
    })
  }

  for (let index = 0; index < sessions.length; index += 400) {
    const { error } = await client
      .from('attendance')
      .upsert(sessions.slice(index, index + 400), {
        onConflict: 'id',
        ignoreDuplicates: true,
      })
    if (error) throw error
  }

  console.log(
    `${profile.full_name} (2023-01-M002): added ${sessions.length} evenly spaced mock check-ins for Mon/Wed/Fri from ${dateOnly(yearStart)} through ${dateOnly(new Date(today.getTime() - 86400000))}; existing dates were skipped.`,
  )
}

main().catch((error) => {
  console.error('Could not seed M002 check-ins:', error.message)
  process.exit(1)
})
