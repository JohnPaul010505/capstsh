// Pure generator for the enrollments dataset (Task 6): membership applications
// sitting in the admin's queue.
//
// An enrollment is an application, not a profile: the person filled in the QR
// signup form and the front desk has not turned them into a member yet. So the
// table carries its own copy of the contact details (full_name, email, phone,
// address, emergency contact) rather than a member_id — that is what makes the
// pending list actionable.
//
// Budget is EXACT, not probabilistic: the queue size is the number the front
// desk works from, so 10 pending / 45 confirmed is asserted, not hoped for.
// (Task 5's renewal seed hit this same trap — an 11% probability roll over 210
// rows produced 8 pending instead of 24.)
//
// IDs: uuid('3e01a010', n) — continuing attendance (…003) through
// notifications (…009).
import { makeRand, uuid, localDate } from './common.mjs'
import { buildPeople, DEMO_DOMAIN } from './users.mjs'

export const ENROLLMENT_ID_PREFIX = '3e01a010'
export const PENDING_COUNT = 10
export const CONFIRMED_COUNT = 45
export const TOTAL = PENDING_COUNT + CONFIRMED_COUNT

const DAY = 86400000
export const addDays = (iso, n) =>
  new Date(Date.parse(`${iso}T00:00:00Z`) + n * DAY).toISOString().slice(0, 10)

// Metro Manila addresses, so the address column reads like a real catchment area
// rather than filler.
const CITIES = [
  'Quezon City', 'Manila', 'Makati', 'Taguig', 'Pasig', 'Mandaluyong', 'Parañaque',
  'Marikina', 'San Juan', 'Las Piñas', 'Caloocan', 'Pasay', 'Mandaluyong',
]
const STREETS = [
  'Tomas Mapua Ave', 'Aurora Blvd', 'Katipunan Ave', 'Rizal St', 'Bonifacio Ave',
  'EDSA', 'Shaw Blvd', ' Ortigas Ave', 'BGC 5th Ave', 'Ortigas Ave ext',
  'Libertad', 'Ayala Ave', 'Quirino Ave', 'Mabini St', 'Roxas Blvd',
]
const RELATIONS = ['Spouse', 'Parent', 'Sibling', 'Friend', 'Child', 'Partner']

// A wider name pool than the member roster, so 55 applicants do not all collide
// with the 987 seeded members' combinations.
const ENROLL_FIRST = [
  'Arnel', 'Betsy', 'Crisanto', 'Divina', 'Efren', 'Flordeliza', 'Generoso',
  'Herma', 'Ismael', 'Jonalyn', 'Kirsten', 'Luigi', 'Manilyn', 'Nestor',
  'Orlene', 'Paz', 'Rodel', 'Sharon', 'Tristan', 'Wilma', 'Yolanda', 'Zaldy',
  'Amihan', 'Benigno', 'Corinna', 'Dalisay', 'Erlinda', 'Ferdinand', 'Gina',
  'Henry', 'Imelda', 'Joel', 'Katherine', 'Lorna', 'Marlon', 'Norma',
]
const ENROLL_LAST = [
  'Abadiano', 'Buenaventura', 'Cabrera', 'Dela Cruz', 'Espino', 'Galang',
  'Hernandez', 'Ignacio', 'Javier', 'Kabigting', 'Legaspi', 'Macapagal',
  'Nepomuceno', 'Ojeda', 'Pangilinan', 'Quiambao', 'Roxas', 'Sison',
  'Tolentino', 'Uy', 'Valencia', 'Yulo', 'Zamora', 'Bernardo', 'Cordero',
  'Dizon', 'Enriquez', 'Fontanilla', 'Gatmaitan', 'Hizon', 'Jacinto',
  'Katigbak', 'Lazatin', 'Maramag', 'Nepomuceno', 'Ozamiz',
]

/**
 * @param {string} adminId  the admin profile id (confirmed_by)
 * @param {{ seed?: number, today?: string }} [opts]
 */
export function buildEnrollments(adminId, opts = {}) {
  const seed = opts.seed ?? 20261004
  const { randInt, pick, shuffle } = makeRand(seed)
  const asOf = opts.today ?? localDate(new Date())

  // Reuse the users generator so names, emails, phones and dates of birth come
  // from the same pool as the member roster — the same person should not look
  // like they were invented by a different generator.
  const people = buildPeople({
    count: TOTAL,
    seed: seed + 1,
    firstNames: ENROLL_FIRST,
    lastNames: ENROLL_LAST,
    emailTag: 'applicant',
  })

  const rows = people.map((p, i) => {
    const pending = i < PENDING_COUNT
    // A pending application is recent — the front desk works a live queue, so
    // these are the days-old entries. A confirmed one is historical.
    const ageDays = pending
      ? randInt(0, 13)
      : randInt(20, 400)
    const createdDay = addDays(asOf, -ageDays)
    const decided = !pending
      ? addDays(createdDay, randInt(1, 5))
      : null
    return {
      full_name: p.fullName,
      email: p.email,
      phone: p.phone,
      date_of_birth: p.dateOfBirth,
      gender: p.gender,
      address: `${randInt(1, 240)} ${pick(STREETS).trim()}, ${pick(CITIES)}`,
      emergency_contact_name: pick(ENROLL_FIRST) + ' ' + pick(ENROLL_LAST),
      emergency_contact_phone: `09${randInt(100000000, 999999999)}`,
      emergency_contact_relation: pick(RELATIONS),
      status: pending ? 'pending' : 'confirmed',
      confirmed_at: decided
        ? new Date(`${decided}T${String(randInt(9, 18)).padStart(2, '0')}:${String(randInt(0, 59)).padStart(2, '0')}:00+08:00`).toISOString()
        : null,
      confirmed_by: decided ? adminId : null,
      created_at: new Date(`${createdDay}T${String(randInt(8, 20)).padStart(2, '0')}:${String(randInt(0, 59)).padStart(2, '0')}:00+08:00`).toISOString(),
    }
  })

  // Newest first: the pending queue is what the admin opens on.
  rows.sort((a, b) => (a.created_at > b.created_at ? -1 : 1))
  rows.forEach((r, i) => { r.id = uuid(ENROLLMENT_ID_PREFIX, i) })
  return { rows, asOf, domain: DEMO_DOMAIN }
}
