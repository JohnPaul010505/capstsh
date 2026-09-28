// Pure generator for the coaching dataset (Task 5, part 1):
// trainer_assignments + trainer_feedback.
//
// Model — mirrors how the live app uses these tables:
//  * TrainerDetailPage (`useTrainer`) shows a trainer's `status = 'active'`
//    members, so assignments are what make a trainer look "loaded" in the UI.
//  * The RLS policies tie feedback to assignments: a trainer may only write
//    feedback for members they are *actively* assigned, so every feedback row
//    here references an active assignment (never an ended one).
//  * `unique(member_id, trainer_id, status)` is a hard constraint, so a member
//    can hold at most one active and at most one ended assignment per trainer.
//    Re-assignment history is modelled as an `ended` row pointing at a
//    DIFFERENT trainer than the current one (a coach leaving / handover).
//  * Active members get a primary active assignment; the highest-frequency
//    attenders additionally get a second (specialist) trainer. Inactive members
//    (profiles.is_active = false) get an ended assignment instead — a coach does
//    not hold an active assignment for someone who stopped training.
//  * Feedback is per active assignment, dated after the assignment, and 70% of
//    entries carry a 1-5 rating (migration 0024's `trainer_feedback_rating_check`
//    allows 1..5 or null) with `rated_at` strictly after `created_at`.
//
// IDs: uuid('3e01a005', n) for assignments, uuid('3e01a006', n) for feedback —
// continuing the sequence used by attendance (…003) and memberships (…004).
import { makeRand, uuid, localDate } from './common.mjs'

export const ASSIGNMENT_ID_PREFIX = '3e01a005'
export const FEEDBACK_ID_PREFIX = '3e01a006'

// Share of high-frequency members that also get a second, specialist trainer.
export const SECOND_TRAINER_SHARE = 0.16
// Share of active members with one historical (ended) assignment from a
// different trainer — this is what populates the "past members" story.
export const ENDED_HISTORY_SHARE = 0.13
// Share of active assignments that receive at least one feedback note.
export const FEEDBACK_COVERAGE = 0.58
// Share of feedback entries the member went on to rate.
export const RATED_SHARE = 0.7

const DAY = 86400000
const SECOND_TRAINER_MIN_CHECKINS = 26
const MAX_FEEDBACK_PER_PAIR = 3

export const addDays = (iso, n) =>
  new Date(Date.parse(`${iso}T00:00:00Z`) + n * DAY).toISOString().slice(0, 10)
export const dayDiff = (a, b) =>
  Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / DAY)

// A coach's note is written on a gym floor, not in a CRM: short, specific, and
// tied to something observable. Templates are grouped by intent so the mix reads
// as a real coaching history rather than shuffled noise.
const PRAISE = [
  'Form on {move} looked sharp today — controlled tempo all the way through. Keep that rep count.',
  'Hit a new personal best on {move}. You have clearly been putting the extra sessions in.',
  'Great consistency this week. {streak} sessions in a row is the best run I have seen from you.',
  'Your squat depth is finally where it should be. That mobility work is paying off.',
  'Solid session. You handled the last set without dropping tempo, which is exactly the goal.',
  'Really pleased with your progress on {move}. Next week we add a little more load.',
]
const CORRECTION = [
  'Watch your lower back on {move} — brace before you descend, not halfway down.',
  'You are drifting forward on the last reps of {move}. Keep the bar over mid-foot.',
  'Slow the eccentric on {move}. Count the descent in your head, three seconds minimum.',
  'Elbows are flaring on {move}. Tuck them in about 45 degrees and the shoulder will stop complaining.',
  'Shorten your range on {move} and own the bottom position. Depth first, load later.',
  'Left side is doing more work than the right on {move}. Film it next session so we can even it out.',
]
const PROGRAM_NOTE = [
  'I have moved you to the {block} block next week. It is a step up, so do not skip the warm-up.',
  'Adding one accessory set for {goal}. Small change, but it targets the weak point we discussed.',
  'We are holding the load steady this week and spending the volume on {move} instead.',
  'New stretch sequence for after training — the {goal} work needs the recovery more than the intensity.',
  'I have dialled the volume down slightly. Two hard sessions a week beats four flat ones.',
]
const RECOVERY = [
  'You looked worn in today, so we kept it light. Eat properly and come back fresh.',
  'Taking a recovery week. The last block was heavy and your body needs the time.',
  'Sleep is where the gains happen. Aim for seven hours before the next heavy session.',
  'Sore from last week? That is fine, but do not train through sharp pain.',
]
const MOTIVATION = [
  'Do not get discouraged by the numbers today. Consistency over months beats a perfect week.',
  'The last three months are the best run you have had. Keep the same schedule.',
  'You are closer than you think. The trend line is moving the right way.',
]

const BLOCKS = ['strength', 'hypertrophy', 'conditioning', 'rehab', 'power']
const GOALS = ['fat loss', 'muscle gain', 'mobility', 'endurance', 'posture']
const MOVES = ['squat', 'deadlift', 'bench press', 'pull-up', 'lunge', 'overhead press', 'row', 'hip thrust']
/** Build one feedback row for an assignment. */
function makeFeedback({ assignment, member, randInt, pick, asOf }) {
  const roll = randInt(1, 100)
  const template = roll <= 42 ? pick(PRAISE)
    : roll <= 68 ? pick(CORRECTION)
      : roll <= 84 ? pick(PROGRAM_NOTE)
        : roll <= 93 ? pick(RECOVERY)
          : pick(MOTIVATION)
  const content = template
    .replace('{move}', () => pick(MOVES))
    .replace('{block}', () => pick(BLOCKS))
    .replace('{goal}', () => pick(GOALS))
    .replace('{streak}', () => String(randInt(3, 9)))

  // Feedback is written after the assignment. It is deliberately capped at
  // YESTERDAY rather than today: a note dated today would have to be placed in
  // the past, and "now" moves while the seed runs, so an exact hour clamp is a
  // source of flaky "dated in the future" failures. Yesterday's note is just as
  // realistic and is always correct.
  const latestDay = addDays(asOf, -1)
  const assignDay = localDate(new Date(assignment.assigned_at))
  const usable = dayDiff(assignDay, latestDay)
  if (usable < 1) return null
  const offset = randInt(1, Math.max(1, Math.floor(usable * 0.8)))
  const createdDay = addDays(assignDay, offset)
  const hour = randInt(8, 20)
  const createdAt = new Date(`${createdDay}T${String(hour).padStart(2, '0')}:${String(randInt(0, 59)).padStart(2, '0')}:00+08:00`).toISOString()

  const rated = randInt(1, 100) <= RATED_SHARE * 100
  // Ratings skew positive (coaching works), but never all 5s.
  const rating = rated ? (randInt(1, 100) <= 62 ? randInt(4, 5) : randInt(3, 4)) : null

  return {
    trainer_id: assignment.trainer_id,
    member_id: assignment.member_id,
    content,
    created_at: createdAt,
    rating,
    // `rated_at` is when the member tapped a star, always after the note.
    rated_at: rating === null ? null
      : new Date(Date.parse(createdAt) + randInt(1, 96) * 3600_000).toISOString(),
  }
}

/**
 * @param {Array}  members   people with { profileId, fullName, joinedAt, isActive, code }
 * @param {Array}  trainers  people with { profileId, fullName, joinedAt }
 * @param {Record} windows   per-member attendance coverage ({first,last,count})
 * @param {{ seed?: number, today?: string }} [opts]
 */
export function buildCoaching(members, trainers, windows, opts = {}) {
  const seed = opts.seed ?? 20260930
  const { randInt, pick, shuffle } = makeRand(seed)
  const asOf = opts.today ?? localDate(new Date())

  if (!members.length) throw new Error('buildCoaching: no members')
  if (!trainers.length) throw new Error('buildCoaching: no trainers')

  const roster = shuffle(trainers.filter((t) => t.profileId))
  if (!roster.length) throw new Error('buildCoaching: no trainers with a profile id')

  const assignments = []
  const seen = new Set() // memberId|trainerId|status — mirrors the unique index
  const add = (a) => {
    const k = `${a.member_id}|${a.trainer_id}|${a.status}`
    if (seen.has(k)) return false
    seen.add(k)
    assignments.push(a)
    return true
  }
  // Assignment moment: at some point after BOTH the member joined and the coach
  // was hired, but not in the future.
  const assignMoment = (m, t, frac) => {
    const joinedDay = localDate(new Date(m.joinedAt))
    const trainerDay = localDate(new Date(t.joinedAt))
    const earliest = joinedDay > trainerDay ? joinedDay : trainerDay
    const slack = dayDiff(earliest, asOf)
    const offset = slack > 1 ? Math.min(slack - 1, Math.floor(slack * frac)) : 0
    return new Date(`${addDays(earliest, Math.max(0, offset))}T09:00:00+08:00`).toISOString()
  }

  // --- 1. primary active assignment for every active member -----------------
  const active = shuffle(members.filter((m) => m.profileId && m.isActive))
  const inactive = members.filter((m) => m.profileId && !m.isActive)

  active.forEach((m, i) => {
    const trainer = roster[i % roster.length]
    add({
      trainer_id: trainer.profileId,
      member_id: m.profileId,
      assigned_at: assignMoment(m, trainer, randInt(0, 80) / 100),
      status: 'active',
    })
  })

  // --- 2. a second, specialist trainer for the keenest attenders -------------
  const keen = active
    .map((m) => ({ m, w: windows[m.profileId] }))
    .filter((x) => x.w && x.w.count >= SECOND_TRAINER_MIN_CHECKINS)
    .sort((a, b) => b.w.count - a.w.count)
  const secondCount = Math.floor(keen.length * SECOND_TRAINER_SHARE)
  const primaryTrainerOf = new Map(
    assignments.filter((a) => a.status === 'active').map((a) => [a.member_id, a.trainer_id]),
  )
  for (const { m, w } of keen.slice(0, secondCount)) {
    const first = primaryTrainerOf.get(m.profileId)
    // Deliberately a different coach from the primary one.
    const alt = roster.filter((t) => t.profileId !== first)
    if (!alt.length) continue
    const trainer = pick(alt)
    add({
      trainer_id: trainer.profileId,
      member_id: m.profileId,
      assigned_at: assignMoment(m, trainer, randInt(15, 75) / 100),
      status: 'active',
    })
  }

  // --- 3. ended history: a handover, or the coach of a lapsed member ---------
  const withHistory = shuffle(active).slice(0, Math.floor(active.length * ENDED_HISTORY_SHARE))
  for (const m of withHistory) {
    const current = primaryTrainerOf.get(m.profileId)
    const alt = roster.filter((t) => t.profileId !== current)
    if (!alt.length) continue
    const previous = pick(alt)
    add({
      trainer_id: previous.profileId,
      member_id: m.profileId,
      assigned_at: assignMoment(m, previous, randInt(5, 40) / 100),
      status: 'ended',
    })
  }
  for (const m of inactive) {
    const trainer = pick(roster)
    add({
      trainer_id: trainer.profileId,
      member_id: m.profileId,
      assigned_at: assignMoment(m, trainer, randInt(0, 80) / 100),
      status: 'ended',
    })
  }

  // --- 4. feedback, always against an ACTIVE assignment ---------------------
  const memberById = new Map(members.map((m) => [m.profileId, m]))
  const feedback = []
  for (const a of assignments.filter((x) => x.status === 'active')) {
    if (!memberById.has(a.member_id)) continue
    if (randInt(1, 100) > FEEDBACK_COVERAGE * 100) continue
    const count = randInt(1, MAX_FEEDBACK_PER_PAIR)
    for (let k = 0; k < count; k++) {
      // makeFeedback returns null when the assignment is too recent to have a
      // note yet (feedback is capped at yesterday).
      const f = makeFeedback({ assignment: a, member: memberById.get(a.member_id), randInt, pick, asOf })
      if (f) feedback.push(f)
    }
  }

  // IDs are assigned in insertion order so the checkpoint can resume anywhere.
  assignments.forEach((a, i) => { a.id = uuid(ASSIGNMENT_ID_PREFIX, i) })
  feedback
    .sort((a, b) => (a.created_at < b.created_at ? -1 : 1))
    .forEach((f, i) => { f.id = uuid(FEEDBACK_ID_PREFIX, i) })

  return { assignments, feedback, asOf, rosterSize: roster.length }
}
