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

// Deterministic PRNG so re-runs produce identical rows (idempotent upserts)
function mulberry32(seed) {
  return function () {
    seed |= 0
    seed = (seed + 0x6D2B79F5) | 0
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}
const rand = mulberry32(20260803)
const randInt = (min, max) => Math.floor(rand() * (max - min + 1)) + min

const uuid = (prefix, n) =>
  `${prefix}-0000-0000-0000-0000000${n.toString(16).padStart(5, '0')}`

// PH (UTC+8) helpers — the app stores real UTC instants and groups by PH wall date.
// `phDate` formats the local (PH) wall date; timestamps are stored as-is via toISOString().
const phDate = (d) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

const chunk = (arr, size) => {
  const out = []
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size))
  return out
}
const upsertChunks = async (table, rows) => {
  for (const c of chunk(rows, 400)) {
    const { error } = await client
      .from(table)
      .upsert(c, { onConflict: 'id', ignoreDuplicates: true })
    if (error) throw new Error(`${table}: ${error.message}`)
  }
}

function businessDays(start, end) {
  const days = []
  const d = new Date(start)
  while (d <= end) {
    if (d.getDay() !== 0) days.push(new Date(d))
    d.setDate(d.getDate() + 1)
  }
  return days
}

const EXERCISES = [
  ['Bench Press', 3, 10, 60],
  ['Squat', 4, 12, 80],
  ['Deadlift', 3, 8, 100],
  ['Overhead Press', 3, 10, 40],
  ['Pull-up', 4, 8, 0],
  ['Barbell Curl', 3, 12, 20],
  ['Leg Press', 4, 12, 120],
  ['Jogging 8 km/h', 1, 0, 0],
  ['Plank', 3, 1, 0],
  ['Lunges', 3, 15, 15],
  ['Lat Pulldown', 4, 10, 50],
  ['Cable Fly', 3, 12, 25],
]
const pick = (arr) => arr[Math.floor(rand() * arr.length)]

async function main() {
  const { data: profile, error: profileError } = await client
    .from('profiles')
    .select('id, full_name, code')
    .eq('code', 'M002')
    .maybeSingle()
  if (profileError) throw profileError
  if (!profile) {
    console.error('M002 not found in profiles — aborting (never touches auth/password)')
    process.exit(1)
  }
  const memberId = profile.id
  console.log(`Seeding M002 (${profile.full_name}, ${profile.id})...`)

  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const monthStart = new Date(today.getFullYear(), today.getMonth(), 1)
  const yesterday = new Date(today.getTime() - 86400000)
  const todayDate = phDate(today)

  // ---- cleanup: drop any previously-seeded rows for today (Aug 3) so the
  // member adds their own exercise/check-in instead of auto-seeded data.
  // The old seed always created today's rows as ids 0..2 in each table,
  // so we delete those exact deterministic ids for today's window. ----
  const todayAttendanceIds = [0, 1, 2].map((n) => uuid('1c01e0b0', n))
  const { error: cleanupAttendanceError } = await client
    .from('attendance')
    .delete()
    .eq('member_id', memberId)
    .eq('check_in_date', todayDate)
    .in('id', todayAttendanceIds)
  if (cleanupAttendanceError) {
    throw new Error(`attendance cleanup (Aug 3): ${cleanupAttendanceError.message}`)
  }
  const tomorrow = new Date(today.getTime() + 86400000)
  const todayWorkoutIds = [0, 1, 2].map((n) => uuid('1c01e0b2', n))
  const { error: cleanupWorkoutError } = await client
    .from('workout_logs')
    .delete()
    .eq('member_id', memberId)
    .gte('logged_at', today.toISOString())
    .lt('logged_at', tomorrow.toISOString())
    .in('id', todayWorkoutIds)
  if (cleanupWorkoutError) {
    throw new Error(`workout_logs cleanup (Aug 3): ${cleanupWorkoutError.message}`)
  }
  console.log(`Aug 3 cleanup: removed seeded attendance + workout rows (member adds their own).`)

  // ---- attendance ----
  const attendance = []
  const workoutDays = [] // { checkIn, checkOut } — days that get workout logs
  let a = 0

  const pushSession = (day, hh, mm, durationMin, closed) => {
    const checkIn = new Date(day.getTime() + (hh * 60 + mm) * 60000)
    const checkOut = closed
      ? new Date(checkIn.getTime() + durationMin * 60000)
      : null
    attendance.push({
      id: uuid('1c01e0b0', a++),
      member_id: memberId,
      check_in_time: checkIn.toISOString(),
      check_in_date: phDate(checkIn),
      check_out_time: checkOut ? checkOut.toISOString() : null,
      expires_at: new Date(checkIn.getTime() + 12 * 3600000).toISOString(),
    })
    return { checkIn, checkOut }
  }

  // Today (Aug 3): intentionally NOT seeded — no attendance/check-ins either.

  // This month (before today): 1 closed session per business day
  for (const day of businessDays(monthStart, yesterday)) {
    const s = pushSession(day, randInt(8, 20), randInt(0, 59), randInt(60, 150), true)
    workoutDays.push(s)
  }

  // Past 7 months of the current year: ~85% of business days
  for (let mo = 0; mo < today.getMonth(); mo++) {
    const start = new Date(today.getFullYear(), mo, 1)
    const end = new Date(today.getFullYear(), mo + 1, 0)
    for (const day of businessDays(start, end)) {
      if (rand() > 0.85) continue
      const s = pushSession(day, randInt(8, 20), randInt(0, 59), randInt(60, 180), true)
      workoutDays.push(s)
    }
  }
  await upsertChunks('attendance', attendance)
  console.log(`Attendance: ${attendance.length} sessions (0 open today — Aug 3 not seeded)`)

  // ---- body_measurements ----
  // Monthly Jan–Jul with a rising weight trend (50 → 59 kg). August is NOT
  // seeded: the real onboarding measurement (60 kg, created when M002 set up
  // their profile) remains the latest point so Settings/BMI show 22.0 · Normal.
  const measRows = []
  let ms = 0
  const measWeights = [50.0, 51.5, 53.0, 54.5, 56.0, 57.5, 59.0]
  for (let mo = 0; mo < 7; mo++) {
    const day = new Date(today.getFullYear(), mo, 5, 10, 0)
    measRows.push({
      id: uuid('1c01e0b4', ms++),
      member_id: memberId,
      weight_kg: measWeights[mo],
      height_cm: 165,
      measured_at: day.toISOString(),
    })
  }
  await upsertChunks('body_measurements', measRows)
  console.log(`Measurements: ${measRows.length} monthly rows (Jan–Jul, 50→59kg); Aug = real onboarding 60kg`)

  // ---- workout_logs ----
  const workouts = []
  let w = 0
  const pushWorkout = (loggedAt, workoutName, name, sets, reps, weight) => {
    workouts.push({
      id: uuid('1c01e0b2', w++),
      member_id: memberId,
      workout_name: workoutName,
      exercise_name: name,
      sets,
      reps,
      weight_kg: weight || null,
      duration_seconds: randInt(30, 90),
      total_calories: randInt(80, 200),
      proof_url: `https://example.com/proof/m002/${loggedAt.toISOString().split('T')[0]}/${workoutName}/${name}.mp4`,
      logged_at: loggedAt.toISOString(),
    })
  }

  // Today (Aug 3): intentionally NOT seeded — the member adds their own
  // exercise from the workout page.

  // Past days: ~85% of workout days get 1–2 sessions with 2–4 exercises each
  for (const { checkIn, checkOut } of workoutDays) {
    if (rand() > 0.85) continue
    const nSessions = randInt(1, 2)
    let sessionOffset = randInt(10, 30) // minutes after check-in for first session
    for (let s = 0; s < nSessions; s++) {
      const workoutName = `Workout S${s + 1}`
      const nEx = randInt(2, 4)
      const base = new Date(checkIn.getTime() + sessionOffset * 60000)
      for (let e = 0; e < nEx; e++) {
        const [name, sets, reps, weight] = pick(EXERCISES)
        // e * 37s offset ensures unique logged_at even when two exercises
        // share the same exercise_name and minute-level timestamp.
        const loggedAt = new Date(base.getTime() + e * randInt(8, 15) * 60000 + e * 37000)
        if (checkOut && loggedAt > checkOut) break
        pushWorkout(loggedAt, workoutName, name, sets, reps, weight)
      }
      sessionOffset += randInt(90, 150) // gap between sessions
    }
  }
  await upsertChunks('workout_logs', workouts)
  console.log(`Workouts: ${workouts.length} logs with workout_name, duration_seconds, total_calories, proof_url`)

  console.log('M002 seed complete. Password untouched (stays 123456789).')
}

main().catch((e) => {
  console.error('Seed failed:', e)
  process.exit(1)
})
