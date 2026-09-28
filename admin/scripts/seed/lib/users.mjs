import { readFileSync, existsSync } from 'node:fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
import { client, makeRand, sleep } from './common.mjs'

const __dirname = dirname(fileURLToPath(import.meta.url))

export const DEMO_DOMAIN = 'demo.fit'
export const MOCK_PASSWORD = 'MockPass123!'

// Gaps burned by deleted probe rows (documented, expected — NOT data errors).
export const KNOWN_CODE_GAPS = ['M003', 'M032', 'M033', 'T008']

const MEMBER_FIRST = [
  'Jose', 'Maria', 'Ana', 'Miguel', 'Liza', 'Carlo', 'Grace', 'Paolo', 'Nina',
  'Mark', 'Ella', 'Ryan', 'Cathy', 'Leo', 'Ivy', 'Dennis', 'Rosa', 'Tomas',
  'Mia', 'Victor', 'Joy', 'Eric', 'Diane', 'Samuel', 'Bianca', 'Marco',
  'Sofia', 'Daniel', 'Katrina', 'Ramon', 'Luz', 'Felipe', 'Corazon',
  'Eduardo', 'Teresita', 'Ricardo', 'Gloria', 'Andres', 'Emmanuel',
  'Patricia', 'Gabriel', 'Christine', 'Rafael', 'Vanessa', 'Enrico', 'Divina',
]
const MEMBER_LAST = [
  'Dela Cruz', 'Santos', 'Ramirez', 'Reyes', 'Bautista', 'Garcia', 'Mendoza',
  'Torres', 'Fernandez', 'Aquino', 'Navarro', 'Villanueva', 'Castillo',
  'Domingo', 'Salazar', 'Ramos', 'Lim', 'Pascual', 'Ocampo', 'Delgado',
  'Sarmiento', 'Campos', 'Palacios', 'Rojas', 'Cortez', 'Mercado', 'Aguilar',
  'Flores', 'Gonzales', 'Rivera', 'Moralos', 'Padilla', 'Velasco',
]
export const TRAINER_FIRST = [
  'Ramil', 'Jenny', 'Marco', 'Aira', 'Ado', 'Kiko', 'Lorna', 'Paolo',
  'Rhea', 'Jonas', 'Mika', 'Enzo',
]
export const TRAINER_LAST = [
  'Villamor', 'Salcedo', 'Dizon', 'Abad', 'Reyes', 'Cruz', 'Bautista',
  'Ocampo', 'Lim', 'Torres',
]

const START_MS = new Date('2020-01-01T00:00:00+08:00').getTime()

const slug = (s) =>
  s.toLowerCase().replace(/[^a-z]+/g, '.').replace(/^\.|\.$/g, '')

// Build a deterministic person list. joinedAt is uniform over
// [2020-01-01, today]; output is sorted ascending so trigger-assigned
// codes rise with seniority when profiles are inserted in order.
export function buildPeople({ count, seed, firstNames, lastNames, emailTag }) {
  const { randInt, shuffle } = makeRand(seed)
  const combos = []
  for (const f of firstNames) for (const l of lastNames) combos.push([f, l])
  if (combos.length < count) {
    throw new Error(`Name pool too small: ${combos.length} combos for ${count} people`)
  }
  const picked = shuffle(combos).slice(0, count)
  const people = picked.map(([f, l], i) => ({
    key: `${emailTag}-${i + 1}`,
    fullName: `${f} ${l}`,
    email: `${slug(f)}.${slug(l)}.${String(i + 1).padStart(4, '0')}@${DEMO_DOMAIN}`,
    joinedAt: new Date(randInt(START_MS, Date.now())).toISOString(),
    gender: randInt(0, 1) === 0 ? 'male' : 'female',
    phone: `09${randInt(100000000, 999999999)}`,
    dateOfBirth: new Date(
      randInt(new Date('1965-01-01').getTime(), new Date('2007-12-31').getTime()),
    ).toISOString().split('T')[0],
    isActive: randInt(1, 100) > 8,
    authId: null,
    profileId: null,
    code: null,
    isNew: true,
  }))
  people.sort((a, b) => (a.joinedAt < b.joinedAt ? -1 : 1))
  return people
}

export const buildMembers = (count, seed = 20200928) =>
  buildPeople({ count, seed, firstNames: MEMBER_FIRST, lastNames: MEMBER_LAST, emailTag: 'member' })

export const buildTrainers = (count, seed = 20200929) =>
  buildPeople({ count, seed, firstNames: TRAINER_FIRST, lastNames: TRAINER_LAST, emailTag: 'coach' })

// Existing profiles (kept, never re-seeded).
export function loadExistingProfiles() {
  const p = resolve(__dirname, '..', '..', '..', 'screenshots', 'demo-data', 'existing-profiles.json')
  if (!existsSync(p)) return []
  const text = readFileSync(p, 'utf8').replace(/^\uFEFF/, '')
  const raw = JSON.parse(text)
  const rows = Array.isArray(raw) ? raw : (raw.value ?? raw.rows ?? [])
  return rows.map((r) => ({
    key: `existing-${r.code}`,
    fullName: r.full_name,
    email: r.email,
    joinedAt: r.created_at,
    authId: r.id,
    profileId: r.id,
    code: r.code,
    role: r.role,
    isNew: false,
  }))
}

// ---- Auth helpers ----
async function fetchAllAuthUsers() {
  const users = []
  let page = 1
  for (;;) {
    const { data, error } = await client.auth.admin.listUsers({ page, perPage: 1000 })
    if (error) throw new Error(`listUsers p${page}: ${error.message}`)
    if (!data?.users?.length) break
    users.push(...data.users)
    if (data.users.length < 1000) break
    page++
  }
  return users
}

export async function ensureAuthUser(email, fullName) {
  const { data, error } = await client.auth.admin.createUser({
    email,
    password: MOCK_PASSWORD,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  })
  if (!error) return { id: data.user.id, created: true }
  if (error.code === 'email_exists' || /already/i.test(error.message)) {
    const users = await fetchAllAuthUsers()
    const found = users.find((u) => u.email?.toLowerCase() === email.toLowerCase())
    if (!found) throw new Error(`email_exists but ${email} not found via listUsers`)
    return { id: found.id, created: false }
  }
  throw new Error(`createUser ${email}: ${error.message}`)
}

async function findProfileByEmail(email) {
  const { data, error } = await client
    .from('profiles')
    .select('id, code')
    .eq('email', email)
    .maybeSingle()
  if (error) throw new Error(`findProfile ${email}: ${error.message}`)
  return data
}

// Stage A — bulk auth creation with a fixed worker pool. Checkpoint the
// manifest via onSave so Ctrl+C / crashes resume without duplicates.
export async function ensureAuthUsers(people, { concurrency = 4, onSave = null, onProgress = null } = {}) {
  const queue = people.filter((p) => p.isNew !== false && !p.authId)
  const total = people.filter((p) => p.isNew !== false).length
  let done = total - queue.length
  let sinceSave = 0

  async function worker() {
    for (;;) {
      const person = queue.shift()
      if (!person) return
      const { id, created } = await ensureAuthUser(person.email, person.fullName)
      person.authId = id
      person.authCreated = created
      done++
      sinceSave++
      onProgress?.(done, total, person)
      if (onSave && sinceSave >= 25) {
        onSave()
        sinceSave = 0
      }
    }
  }

  await Promise.all(Array.from({ length: concurrency }, () => worker()))
  onSave?.()
  return people
}

// Stage B — sequential profile inserts (NO code: the auto_uid trigger
// assigns M/T numbers in insert order). Pass joinedAt-ascending input so
// codes rise with seniority. Backdates created_at/updated_at to joinedAt.
export async function ensureProfiles(people, role, opts = {}) {
  const { onSave = null, onProgress = null } = opts
  const ordered = [...people]
    .filter((p) => p.isNew !== false && !p.profileId)
    .sort((a, b) => (a.joinedAt < b.joinedAt ? -1 : 1))
  const total = people.filter((p) => p.isNew !== false).length
  let done = total - ordered.length
  let sinceSave = 0

  for (const person of ordered) {
    if (!person.authId) throw new Error(`No authId for ${person.email} — run Stage A first`)
    const existing = await findProfileByEmail(person.email)
    if (existing) {
      person.profileId = existing.id
      person.code = existing.code
    } else {
      const { data, error } = await client
        .from('profiles')
        .insert({
          id: person.authId,
          role,
          full_name: person.fullName,
          email: person.email,
          phone: person.phone,
          gender: person.gender,
          date_of_birth: person.dateOfBirth,
          is_active: person.isActive,
        })
        .select('id, code')
        .single()
      if (error) throw new Error(`insert profile ${person.email}: ${error.message}`)
      person.profileId = data.id
      person.code = data.code
      const { error: backdateError } = await client
        .from('profiles')
        .update({ created_at: person.joinedAt, updated_at: person.joinedAt })
        .eq('id', person.profileId)
      if (backdateError) throw new Error(`backdate ${person.email}: ${backdateError.message}`)
    }
    done++
    sinceSave++
    onProgress?.(done, total, person)
    if (onSave && sinceSave >= 25) {
      onSave()
      sinceSave = 0
    }
    await sleep(40)
  }
  onSave?.()
  return people
}

