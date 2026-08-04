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

// Deterministic PRNG for stable data
function mulberry32(seed) {
  return function () {
    seed |= 0; seed = (seed + 0x6D2B79F5) | 0
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}
const rand = mulberry32(20260731)
const randInt = (min, max) => Math.floor(rand() * (max - min + 1)) + min
const pick = (arr) => arr[Math.floor(rand() * arr.length)]

// Deterministic UUID from a number (valid v4-format hex)
const uuid = (prefix, n) =>
  `${prefix}-0000-0000-0000-0000000${n.toString(16).padStart(5, '0')}`

// Local (PH, UTC+8) time helpers — Supabase stores timestamptz
const PH_OFFSET = 8 * 60 * 60 * 1000
const localIso = (d) => new Date(d.getTime() - PH_OFFSET).toISOString()
const localDate = (d) => localIso(d).split('T')[0]

const sleep = (ms) => new Promise((r) => setTimeout(r, ms))
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

const MOCK_PASSWORD = 'MockPass123!'
const MOCK_EMAIL_DOMAIN = 'mock.fit'
const MEMBER_NAMES = [
  'Juan Dela Cruz', 'Maria Santos', 'Jose Ramirez', 'Ana Reyes', 'Miguel Bautista',
  'Liza Garcia', 'Carlo Mendoza', 'Grace Torres', 'Paolo Fernandez', 'Nina Aquino',
  'Mark Navarro', 'Ella Villanueva', 'Ryan Castillo', 'Cathy Domingo', 'Leo Salazar',
  'Ivy Ramos', 'Dennis Lim', 'Rosa Pascual', 'Tomas Ocampo', 'Mia Delgado',
  'Victor Sarmiento', 'Joy Campos', 'Eric Palacios', 'Diane Rojas', 'Sam Cortez',
]
const TRAINER_NAMES = ['Coach Ramil', 'Coach Jen', 'Coach Marco', 'Coach Aira']
const EXERCISES = [
  ['Bench Press', 3, 10, 60], ['Squat', 4, 12, 80], ['Deadlift', 3, 8, 100],
  ['Overhead Press', 3, 10, 40], ['Pull-ups', 4, 8, 0], ['Bicep Curls', 3, 12, 20],
  ['Leg Press', 4, 12, 120], ['Treadmill', 1, 0, 0], ['Plank', 3, 1, 0],
  ['Lunges', 3, 15, 15], ['Lat Pulldown', 4, 10, 50], ['Cable Fly', 3, 12, 25],
]
const MEALS = [
  ['Breakfast', 'Oatmeal with banana and honey', 320, 10, 55, 6],
  ['Lunch', 'Chicken rice bowl with vegetables', 550, 35, 60, 15],
  ['Dinner', 'Grilled fish with quinoa', 480, 40, 45, 12],
  ['Snack', 'Protein shake with almonds', 250, 25, 10, 12],
  ['Breakfast', 'Scrambled eggs and whole wheat toast', 350, 22, 30, 18],
  ['Lunch', 'Beef sinigang with rice', 520, 30, 65, 14],
  ['Dinner', 'Chicken adobo with brown rice', 560, 38, 50, 18],
  ['Snack', 'Greek yogurt with granola', 220, 18, 25, 6],
]
const FEEDBACK_NOTES = [
  'Very helpful with my form, great coach!',
  'Always pushes me to do better. Highly recommended.',
  'Explains exercises clearly and patiently.',
  'Great motivation every session.',
  'Needs to be more punctual sometimes.',
  'Awesome guidance on my diet plan.',
  'Very approachable and supportive.',
  'Made me feel comfortable in the gym.',
  'Great progress with his program.',
  'Kind and professional coach.',
  'Gives clear instructions for each exercise.',
  'Really helped me fix my squat form.',
]

// Business days (Mon–Sat) from start to end
function businessDays(start, end) {
  const days = []
  const d = new Date(start)
  while (d <= end) {
    const dow = d.getDay()
    if (dow !== 0) days.push(new Date(d))
    d.setDate(d.getDate() + 1)
  }
  return days
}

async function findProfileByEmail(email) {
  const { data } = await client.from('profiles').select('id').eq('email', email).maybeSingle()
  return data?.id ?? null
}

async function findAuthUserByEmail(email) {
  const { data, error } = await client.auth.admin.listUsers({ page: 1, perPage: 1000 })
  if (error) throw error
  return data?.users?.find((u) => u.email === email) ?? null
}

// Creates auth user + profile. Backdates created_at so Member Growth chart spans Jan–Jul.
async function ensureUser({ email, fullName, role, createdAt }) {
  const existingId = await findProfileByEmail(email)
  if (existingId) return existingId

  let authUserId
  const { data: authUser, error: authError } = await client.auth.admin.createUser({
    email,
    password: MOCK_PASSWORD,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  })
  if (authError && authError.code === 'email_exists') {
    // Partial state from a previous failed run: auth user exists, profile missing.
    const existing = await findAuthUserByEmail(email)
    if (!existing) throw authError
    authUserId = existing.id
  } else if (authError) {
    throw authError
  } else {
    authUserId = authUser.user.id
  }

  const { error: profileError } = await client.from('profiles').insert({
    id: authUserId,
    role,
    full_name: fullName,
    email,
    phone: `09${randInt(100000000, 999999999)}`,
    gender: rand() > 0.5 ? 'male' : 'female',
    is_active: true,
  })
  if (profileError) throw profileError

  const { error: backdateError } = await client
    .from('profiles')
    .update({ created_at: createdAt, updated_at: createdAt })
    .eq('id', authUserId)
  if (backdateError) throw backdateError

  return authUserId
}

async function seedAdmin() {
  const email = 'admin@fitness.com'
  const existing = await findProfileByEmail(email)
  if (existing) return existing
  let authUserId
  const { data: authUser, error } = await client.auth.admin.createUser({
    email, password: 'Admin123!', email_confirm: true,
    user_metadata: { full_name: 'System Admin' },
  })
  if (error && error.code === 'email_exists') {
    const existing = await findAuthUserByEmail(email)
    if (!existing) throw error
    authUserId = existing.id
  } else if (error) {
    throw error
  } else {
    authUserId = authUser.user.id
  }
  const { error: pe } = await client.from('profiles').insert({
    id: authUserId, role: 'admin', full_name: 'System Admin', email,
  })
  if (pe) throw pe
  return authUserId
}

async function seedMembersAndTrainers() {
  const adminId = await seedAdmin()
  const trainerIds = []
  for (let i = 0; i < TRAINER_NAMES.length; i++) {
    trainerIds.push(await ensureUser({
      email: `trainer${i + 1}@${MOCK_EMAIL_DOMAIN}`,
      fullName: TRAINER_NAMES[i],
      role: 'trainer',
      createdAt: new Date(2026, 0, randInt(5, 20)).toISOString(),
    }))
  }
  const memberIds = []
  for (let i = 0; i < MEMBER_NAMES.length; i++) {
    const monthsAgo = randInt(0, 5)
    const created = new Date(2026, Math.min(6, monthsAgo), randInt(5, 28), randInt(8, 18), randInt(0, 59))
    memberIds.push(await ensureUser({
      email: `member${i + 1}@${MOCK_EMAIL_DOMAIN}`,
      fullName: MEMBER_NAMES[i],
      role: 'member',
      createdAt: created.toISOString(),
    }))
  }
  // Memberships: first 16 = Daily, rest = Monthly
  const today = new Date()
  const plans = memberIds.map((id, i) => {
    const isDaily = i < 16
    const start = new Date(2026, randInt(0, 5), randInt(1, 28))
    let end
    if (isDaily) {
      end = new Date(today)
    } else {
      const monthOffset = randInt(0, 3)
      end = new Date(2026, Math.min(6, 4 + monthOffset), randInt(1, 28))
    }
    // expiring soon: members 16 & 17 (end within 7 days); expired: 18,19,20; cancelled: 21
    if (i === 16) end = new Date(today.getTime() + randInt(1, 3) * 86400000)
    if (i === 17) end = new Date(today.getTime() + randInt(4, 7) * 86400000)
    if (i === 18 || i === 19 || i === 20) end = new Date(2026, 5, randInt(1, 28))
    const status = i === 20 ? 'cancelled' : end < today ? 'expired' : 'active'
    return {
      id: uuid('1c01e0a1', i),
      member_id: id,
      plan_name: isDaily ? 'Daily' : 'Monthly',
      price: isDaily ? 150 : pick([800, 1000, 1200]),
      start_date: localDate(start),
      end_date: localDate(end),
      status,
    }
  })
  await upsertChunks('memberships', plans)

  // Assignments: T001:8, T002:7, T003:6, T004:4
  const distribution = [8, 7, 6, 4]
  const assignments = []
  let m = 0
  for (let t = 0; t < trainerIds.length; t++) {
    for (let k = 0; k < distribution[t]; k++) {
      assignments.push({
        id: uuid('1c01e0a2', m),
        trainer_id: trainerIds[t],
        member_id: memberIds[m],
        status: 'active',
        assigned_at: localIso(new Date(2026, randInt(0, 4), randInt(1, 28), 9)),
      })
      m++
    }
  }
  await upsertChunks('trainer_assignments', assignments)
  return { adminId, trainerIds, memberIds }
}

async function seedAttendance(memberIds, trainerIds) {
  const start = new Date(2026, 0, 5)
  const end = new Date(2026, 6, 31)
  const days = businessDays(start, end)
  const rows = []
  const openToday = new Set()

  // 4 inactive daily members: no check-ins after Jul 15 (indices 12..15)
  const inactiveIdx = new Set([12, 13, 14, 15])
  const lastActiveFor = new Map()
  let idx = 0
  for (const day of days) {
    const isToday = localDate(day) === localDate(end)
    const checked = []
    memberIds.forEach((id, i) => {
      if (inactiveIdx.has(i) && day > new Date(2026, 6, 15)) return
      if (day < new Date(2026, 0, 5)) return
      if (rand() > 0.72) return // ~72% show rate
      checked.push({ id, i })
      lastActiveFor.set(i, day)
    })
    for (const { id } of checked) {
      const hh = randInt(6, 21)
      const mm = randInt(0, 59)
      const checkIn = new Date(day.getTime() + (hh * 60 + mm) * 60000)
      const closed = rand() > 0.08
      const checkOut = closed
        ? new Date(checkIn.getTime() + randInt(60, 180) * 60000)
        : null
      rows.push({
        id: uuid('1c01e0a3', idx++),
        member_id: id,
        check_in_time: localIso(checkIn),
        check_in_date: localDate(day),
        check_out_time: checkOut ? localIso(checkOut) : null,
        expires_at: localIso(new Date(checkIn.getTime() + 12 * 3600000)),
      })
      if (isToday && checkOut === null) openToday.add(id)
    }
    // 1-2 trainer check-ins per week
    if (rand() < 0.28) {
      const tid = pick(trainerIds)
      const hh = randInt(6, 12)
      const checkIn = new Date(day.getTime() + (hh * 60 + randInt(0, 59)) * 60000)
      rows.push({
        id: uuid('1c01e0a3', idx++),
        member_id: tid,
        check_in_time: localIso(checkIn),
        check_in_date: localDate(day),
        check_out_time: localIso(new Date(checkIn.getTime() + randInt(60, 120) * 60000)),
        expires_at: localIso(new Date(checkIn.getTime() + 12 * 3600000)),
      })
    }
  }

  // Ensure 3-4 open sessions today
  if (openToday.size < 3) {
    const candidates = memberIds.filter((id, i) => !inactiveIdx.has(i) && !openToday.has(id))
    while (openToday.size < 4 && candidates.length > 0) {
      const id = candidates.splice(0, 1)[0]
      const now = new Date()
      const checkIn = new Date(now.getTime() - randInt(30, 180) * 60000)
      rows.push({
        id: uuid('1c01e0a3', idx++),
        member_id: id,
        check_in_time: localIso(checkIn),
        check_in_date: localDate(checkIn),
        check_out_time: null,
        expires_at: localIso(new Date(checkIn.getTime() + 12 * 3600000)),
      })
      openToday.add(id)
    }
  }
  await upsertChunks('attendance', rows)
  console.log(`Seeded ${rows.length} attendance sessions, ${openToday.size} open today`)
  return { lastActiveFor, openToday }
}

async function seedWorkoutsMealsMeasurements(memberIds, lastActiveFor) {
  const workoutRows = []
  const mealRows = []
  const measRows = []
  const start = new Date(2026, 0, 5)
  const end = new Date(2026, 6, 31)
  const days = businessDays(start, end)
  let w = 0, mrow = 0, msz = 0

  memberIds.forEach((memberId, i) => {
    // Measurements: monthly Jan–Jul; weekly for members 0-2 (prediction density)
    const isWeekly = i < 3
    let baseWeight = randInt(55, 95)
    const height = randInt(155, 185)
    const trend = rand() > 0.5 ? -0.4 : 0.3
    let dayCursor = new Date(2026, 0, 5)
    while (dayCursor <= end) {
      baseWeight = Math.max(45, Math.round((baseWeight + trend) * 10) / 10)
      measRows.push({
        id: uuid('1c01e0a4', msz++),
        member_id: memberId,
        weight_kg: baseWeight,
        height_cm: height,
        body_fat_pct: Math.round((randInt(15, 30) + baseWeight / 10) * 10) / 10,
        measured_at: localIso(new Date(dayCursor.getTime() + randInt(6, 10) * 3600000)),
      })
      dayCursor.setDate(dayCursor.getDate() + (isWeekly ? 7 : 30))
    }
    // Workouts + meals on 40% of attendance days
    const activeDays = days.filter((d) => {
      const cutoff = lastActiveFor.get(i)
      return d <= (cutoff ?? new Date(2026, 5, 1))
    })
    for (const day of activeDays) {
      if (rand() > 0.4) continue
      const base = new Date(day.getTime() + (randInt(7, 19) * 60 + randInt(0, 59)) * 60000)
      const nEx = randInt(2, 4)
      for (let e = 0; e < nEx; e++) {
        const [name, sets, reps, weight] = pick(EXERCISES)
        workoutRows.push({
          id: uuid('1c01e0a5', w++),
          member_id: memberId,
          exercise_name: name,
          sets,
          reps,
          weight_kg: weight || null,
          duration_minutes: randInt(30, 90),
          logged_at: localIso(new Date(base.getTime() + e * randInt(8, 15) * 60000)),
        })
      }
      const nMeals = randInt(2, 3)
      for (let e = 0; e < nMeals; e++) {
        const [mealType, food, cal, protein, carbs, fat] = pick(MEALS)
        mealRows.push({
          id: uuid('1c01e0a6', mrow++),
          member_id: memberId,
          meal_type: mealType,
          food_name: food,
          calories: cal,
          protein_g: protein,
          carbs_g: carbs,
          fat_g: fat,
          meal_time: localIso(new Date(base.getTime() + e * 60 * 60000)),
        })
      }
    }
  })
  await upsertChunks('workout_logs', workoutRows)
  await upsertChunks('meal_logs', mealRows)
  await upsertChunks('body_measurements', measRows)
  console.log(`Seeded ${workoutRows.length} workouts, ${mealRows.length} meals, ${measRows.length} measurements`)
}

async function seedGoals(memberIds) {
  const rows = []
  let i = 0
  memberIds.forEach((id) => {
    const goalDefs = [
      ['Lose 5kg', 'Lose weight', 5, randInt(1, 4), 'kg'],
      ['Bench 60kg', 'Increase strength', 60, randInt(20, 55), 'kg'],
    ]
    goalDefs.forEach(([title, desc, target, current, unit], k) => {
      rows.push({
        id: uuid('1c01e0a7', i++),
        member_id: id,
        title,
        description: desc,
        target_value: target,
        current_value: current,
        unit,
        deadline: localDate(new Date(2026, 7, randInt(1, 28))),
        status: k === 0 ? pick(['active', 'in_progress']) : 'active',
        created_at: localIso(new Date(2026, randInt(0, 3), randInt(1, 28))),
      })
    })
  })
  await upsertChunks('goals', rows)
}

async function seedChat(memberIds, trainerIds) {
  const { data: assignments } = await client
    .from('trainer_assignments')
    .select('member_id, trainer_id')
    .eq('status', 'active')
  const roomRows = []
  const msgRows = []
  assignments.forEach((a, i) => {
    roomRows.push({
      id: uuid('1c01e0a8', i),
      participant_one: a.trainer_id,
      participant_two: a.member_id,
      created_at: localIso(new Date(2026, randInt(0, 4), randInt(1, 28))),
    })
    const n = randInt(3, 8)
    for (let k = 0; k < n; k++) {
      const sender = k % 2 === 0 ? a.member_id : a.trainer_id
      msgRows.push({
        id: uuid('1c01e0a9', i * 10 + k),
        room_id: roomRows[i].id,
        sender_id: sender,
        content: pick([
          'Good session today!', 'How was the workout?', 'Keep it up!',
          'Any soreness after yesterday?', 'Remember to hydrate.',
          'Great job on the new PR!', 'See you next session!',
          'Try the new stretch routine.', 'Proud of your progress!',
          'Rest day tomorrow, stay active.', 'Let me know if you need help.',
        ]),
        created_at: localIso(new Date(2026, randInt(1, 6), randInt(1, 28), randInt(8, 20), randInt(0, 59))),
      })
    }
  })
  await upsertChunks('chat_rooms', roomRows)
  await upsertChunks('chat_messages', msgRows)
  console.log(`Seeded ${roomRows.length} chat rooms, ${msgRows.length} messages`)
}

async function seedFeedback(memberIds) {
  const rows = []
  let i = 0
  for (const id of memberIds.slice(0, 14)) {
    const { data: a } = await client
      .from('trainer_assignments')
      .select('trainer_id')
      .eq('member_id', id)
      .eq('status', 'active')
      .maybeSingle()
    const rowIdx = i
    rows.push({
      id: uuid('1c01e0aa', i++),
      member_id: id,
      trainer_id: rowIdx <= 2 ? null : (a?.trainer_id ?? null), // 2 coachless feedback entries
      content: pick(FEEDBACK_NOTES),
      created_at: localIso(new Date(2026, randInt(3, 6), randInt(1, 28), randInt(9, 21))),
    })
  }
  await upsertChunks('trainer_feedback', rows)
}

async function seedNotifications(memberIds) {
  const rows = []
  for (let i = 0; i < 8; i++) {
    rows.push({
      id: uuid('1c01e0ab', i),
      user_id: pick(memberIds),
      title: pick(['Workout reminder', 'New goal achieved', 'Membership expiring soon', 'Coach message', 'Welcome to the gym']),
      body: 'This is a sample notification for demo data.',
      read: rand() > 0.5,
      created_at: localIso(new Date(2026, randInt(5, 6), randInt(1, 28), randInt(8, 20))),
    })
  }
  await upsertChunks('notifications', rows)
}

async function seedEnrollments(adminId) {
  const emails = ['new.member1@mock.fit', 'new.member2@mock.fit']
  for (let i = 0; i < emails.length; i++) {
    const { data: exists } = await client
      .from('enrollments').select('id').eq('email', emails[i]).maybeSingle()
    if (exists) continue
    const { error } = await client.from('enrollments').insert({
      id: uuid('1c01e0ac', i),
      full_name: i === 0 ? 'Kim Ocampo' : 'Aileen Navarro',
      email: emails[i],
      phone: `09${randInt(100000000, 999999999)}`,
      status: 'pending',
      created_at: localIso(new Date(2026, 6, randInt(20, 30), randInt(9, 18))),
    })
    if (error) throw error
  }
  const confirmed = [
    ['Bea Marquez', 'bea.marquez@mock.fit'],
    ['Noel Ignacio', 'noel.ignacio@mock.fit'],
    ['Faye Valdez', 'faye.valdez@mock.fit'],
  ]
  for (let i = 0; i < confirmed.length; i++) {
    const { data: exists } = await client
      .from('enrollments').select('id').eq('email', confirmed[i][1]).maybeSingle()
    if (exists) continue
    const { error } = await client.from('enrollments').insert({
      id: uuid('1c01e0ac', i + 10),
      full_name: confirmed[i][0],
      email: confirmed[i][1],
      phone: `09${randInt(100000000, 999999999)}`,
      status: 'confirmed',
      confirmed_at: localIso(new Date(2026, 6, randInt(20, 29), randInt(9, 18))),
      confirmed_by: adminId,
      created_at: localIso(new Date(2026, 6, randInt(15, 25))),
    })
    if (error) throw error
  }
  console.log('Seeded enrollments')
}

async function main() {
  console.log('Seeding dev data (Jan 5 – Jul 31 2026)...')
  const { adminId, trainerIds, memberIds } = await seedMembersAndTrainers()
  const { lastActiveFor } = await seedAttendance(memberIds, trainerIds)
  await seedWorkoutsMealsMeasurements(memberIds, lastActiveFor)
  await seedGoals(memberIds)
  await seedChat(memberIds, trainerIds)
  await seedFeedback(memberIds)
  await seedNotifications(memberIds)
  await seedEnrollments(adminId)
  console.log('Seed complete. Mock password for all users: MockPass123!')
}
main().catch((e) => { console.error('Seed failed:', e); process.exit(1) })
