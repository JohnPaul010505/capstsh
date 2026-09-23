// admin/scripts/probe-attendance-today.mjs
// Read-only diagnosis for "trainer QR works but nothing shows on admin attendance":
// compares the UTC "today" the admin page queries against the PH-local date the
// mobile app writes (check_in_date), then lists today's rows per role.
import { config } from 'dotenv'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
config({ path: resolve(dirname(fileURLToPath(import.meta.url)), '..', '.env') })
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.VITE_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { autoRefreshToken: false, persistSession: false } },
)

const utcToday = new Date().toISOString().split('T')[0]
const manilaParts = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Asia/Manila',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
}).format(new Date())
console.log(`utc-today=${utcToday}  manila-today=${manilaParts}  match=${utcToday === manilaParts}`)

for (const day of new Set([utcToday, manilaParts])) {
  const { data, error } = await supabase
    .from('attendance')
    .select('id, member_id, check_in_date, check_in_time, check_out_time, profiles!attendance_member_id_fkey(full_name, role, code)')
    .eq('check_in_date', day)
    .order('check_in_time', { ascending: false })
  if (error) {
    console.log(`FAIL  ${day} -- ${error.message}`)
    continue
  }
  const members = (data ?? []).filter(r => r.profiles?.role !== 'trainer').length
  const trainers = (data ?? []).filter(r => r.profiles?.role === 'trainer').length
  console.log(`rows for check_in_date=${day}: total=${(data ?? []).length} members=${members} trainers=${trainers}`)
  for (const r of (data ?? []).slice(0, 10)) {
    console.log(`  ${r.check_in_time}  ${r.profiles?.full_name ?? '?'} (${r.profiles?.role ?? '?'}) in=${r.check_in_time?.slice(11, 16) ?? '-'} out=${r.check_out_time?.slice(11, 16) ?? 'open'}`)
  }
}

// ---- verification: migration file present and trigger SQL sane ----
const fs = await import('fs')
const sql = fs.readFileSync('supabase/migrations/0028_attendance_notifications.sql', 'utf8')
for (const needle of [
  'security definer',
  'after insert or update on attendance',
  'OLD.check_out_time is null',
  'Checked In',
  'Checked Out',
]) {
  if (!sql.toLowerCase().includes(needle.toLowerCase())) {
    console.log(`MIGRATION MISSING: ${needle}`)
    process.exit(1)
  }
}
console.log('migration 0028_attendance_notifications.sql: required clauses present')

// ---- verification: admin default now matches PH day ----
const shim = await import('fs')
const tsx = shim.readFileSync('admin/src/features/attendance/pages/AttendancePage.tsx', 'utf8')
if (tsx.includes('new Date().toISOString().split')) {
  console.log('ADMIN DATE STILL UTC — fix missing')
  process.exit(1)
}
if (!tsx.includes('localToday()')) {
  console.log('ADMIN localToday() helper missing')
  process.exit(1)
}
console.log('admin AttendancePage: UTC default replaced with local-day helper')
console.log('DONE: service-role read-only checks passed; DB trigger + admin fix ready for your device test')