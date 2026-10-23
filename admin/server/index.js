import { createPredictionHandler } from './predictionEngine.js'
﻿import { config } from 'dotenv'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
config({ path: resolve(dirname(fileURLToPath(import.meta.url)), '..', '.env') })
import express from 'express'
import cors from 'cors'
import { createClient } from '@supabase/supabase-js'
import { confirmEnrollment, rejectEnrollment } from './enrollmentActions.js'

const app = express()
app.use(cors({ origin: '*', credentials: true }))
app.use(express.json())

const supabaseUrl = process.env.VITE_SUPABASE_URL
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!supabaseUrl || !serviceRoleKey) {
  console.error('Missing VITE_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY')
  process.exit(1)
}

const adminClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
})

// Base URL of the Python predictions service. Keep in sync with PORT in
// ai-service/.env (default 8001 - port 3001 belongs to this Express server).
const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://localhost:8001'

// Trainers own their personal details; recipients are resolved server-side.
app.post('/api/trainer/profile', async (req, res) => {
  const token = req.headers.authorization?.replace(/^Bearer\s+/i, '')
  if (!token) return res.status(401).json({ error: 'Sign in required' })
  const { data: auth, error: authError } = await adminClient.auth.getUser(token)
  if (authError || !auth.user) return res.status(401).json({ error: 'Invalid session' })
  const { data: previous } = await adminClient.from('profiles').select('*').eq('id', auth.user.id).single()
  if (previous?.role !== 'trainer') return res.status(403).json({ error: 'Trainer account required' })
  const allowed = ['full_name', 'phone', 'date_of_birth', 'gender', 'civil_status', 'religion', 'religion_other', 'address', 'emergency_contact_name', 'emergency_contact_phone', 'specialty', 'available_days']
  const updates = Object.fromEntries(allowed.filter(key => Object.hasOwn(req.body, key)).map(key => [key, req.body[key]]))
  if (Object.values(updates).some(value => value !== null && (typeof value !== 'string' || value.length > 2000))) return res.status(400).json({ error: 'Invalid profile value' })
  try {
    const { data: saved, error } = await adminClient.from('profiles').update(updates).eq('id', auth.user.id).select().single()
    if (error) throw error
    let notificationWarning = null
    if (saved.specialty !== previous.specialty || saved.available_days !== previous.available_days) {
      const { data: assignments, error: assignmentError } = await adminClient.from('trainer_assignments').select('member_id').eq('trainer_id', auth.user.id).eq('status', 'active')
      const recipients = [...new Set((assignments ?? []).map(row => row.member_id))]
      const { error: notificationError } = assignmentError ? { error: assignmentError } : recipients.length ? await adminClient.from('notifications').insert(recipients.map(user_id => ({ user_id, title: 'Trainer details updated', sender_name: saved.full_name, body: `${saved.full_name} updated their details. Specialty: ${saved.specialty || 'Not specified'}. Availability: ${saved.available_days || 'Not provided'}.` }))) : { error: null }
      if (notificationError) notificationWarning = 'Details saved, but member notifications could not be sent.'
    }
    res.json({ profile: saved, notificationWarning })
  } catch (error) { res.status(500).json({ error: 'Could not save trainer details' }) }
})

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', routes: ['enroll', 'users', 'update-email', 'delete-user', 'assignable-members', 'assign-trainer', 'unassign-trainer', 'backfill-auth', 'backfill-codes', 'ai/predictions', 'plans/check-daily-completions', 'plans/check-weekly-completions'] })
})

app.post('/api/enroll', async (req, res) => {
  const { fullName, email, phone, dateOfBirth, gender, civilStatus, religion, religionOther, address, emergencyContactName, emergencyContactPhone } = req.body
  if (!fullName || !email) return res.status(400).json({ error: 'Name and email are required' })
  try {
    const { error } = await adminClient.from('enrollments').insert({
      full_name: fullName, email, phone: phone || null,
      date_of_birth: dateOfBirth || null, gender: gender || null,
      civil_status: civilStatus || null, religion: religion || null,
      religion_other: religion === 'other' ? religionOther || null : null,
      address: address || null, status: 'pending',
      emergency_contact_name: emergencyContactName || null,
      emergency_contact_phone: emergencyContactPhone || null,
    })
    if (error) throw error
    res.json({ success: true })
  } catch (err) {
    res.status(500).json({ error: err?.message || 'Failed to submit enrollment' })
  }
})

app.post('/api/users', async (req, res) => {
  const { email, password, fullName, role, phone, dateOfBirth, gender, civilStatus, religion, religionOther, address, emergencyContactName, emergencyContactPhone, specialty, availableDays } = req.body

  if (!email || !password || !fullName || !role) {
    return res.status(400).json({ error: 'Missing required fields: email, password, fullName, role' })
  }

  try {
    const { data: authUser, error: authError } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName },
    })

    if (authError) throw authError

    const profileData = {
      id: authUser.user.id,
      role,
      full_name: fullName,
      email,
      phone: phone || null,
      specialty: specialty || null,
      available_days: availableDays || null,
      date_of_birth: dateOfBirth || null,
      gender: gender || null,
      civil_status: civilStatus || null,
      religion: religion || null,
      religion_other: religion === 'other' ? religionOther || null : null,
      address: address || null,
      emergency_contact_name: emergencyContactName || null,
      emergency_contact_phone: emergencyContactPhone || null,
    }

    const { data: profile, error: profileError } = await adminClient.from('profiles').insert(profileData).select('code').single()
    if (profileError) throw profileError

    res.json({ success: true, userId: authUser.user.id, code: profile.code })
  } catch (err) {
    console.error('Create user error:', err)
    const message = err?.message || err?.error_description || JSON.stringify(err)
    const details = err?.code || err?.status || ''
    console.error('Error details:', { message, details })
    res.status(500).json({ error: message, details })
  }
})

app.post('/api/confirm-enrollment', confirmEnrollment)
app.post('/api/reject-enrollment', rejectEnrollment)

app.post('/api/delete-user', async (req, res) => {
  const { userId } = req.body

  if (!userId) {
    return res.status(400).json({ error: 'Missing userId' })
  }

  try {
    const { error: authError } = await adminClient.auth.admin.deleteUser(userId)
    if (authError) throw authError

    const { error: profileError } = await adminClient.from('profiles').delete().eq('id', userId)
    if (profileError) throw profileError

    res.json({ success: true })
  } catch (err) {
    console.error('Delete user error:', err)
    const message = err?.message || JSON.stringify(err)
    res.status(500).json({ error: message })
  }
})

app.post('/api/update-email', async (req, res) => {
  const { userId, email } = req.body

  if (!userId || !email) {
    return res.status(400).json({ error: 'Missing userId or email' })
  }

  try {
    // profiles.email is what the app's login lookup reads, so the caller has
    // already decided this is the address; write it into auth.users too.
    // Password is untouched, so the member's existing password keeps working.
    const { error } = await adminClient.auth.admin.updateUserById(userId, {
      email,
      email_confirm: true,
    })
    if (error) throw error

    res.json({ success: true })
  } catch (err) {
    console.error('Update email error:', err)
    const message = err?.message || JSON.stringify(err)
    res.status(500).json({ error: message })
  }
})

// A member may work with up to five active trainers; inactive history does not
// count. Shared by the chooser and the assign endpoint so both agree.
const MEMBER_TRAINER_LIMIT = 5

/**
 * Reads every row of a paged PostgREST query - the JS client returns at most
 * 1000 rows per select, which a whole-gym roster can exceed.
 */
async function fetchAllRows(buildQuery) {
  const pageSize = 1000
  const rows = []
  for (let offset = 0; ; offset += pageSize) {
    const { data, error } = await buildQuery().range(offset, offset + pageSize - 1)
    if (error) throw error
    rows.push(...(data ?? []))
    if ((data ?? []).length < pageSize) break
  }
  return rows
}

/**
 * Members the admin can still add to this trainer:
 *  - not actively assigned to them already (no duplicate pair), and
 *  - fewer than five active trainers (members at the cap are hidden).
 * Members who work with other trainers stay eligible and carry their active
 * count, so the chooser can show "2 of 5 trainers" instead of blocking them.
 * Served from the service-role client so the answer never depends on row-level
 * security or on a stale client cache.
 */
app.get('/api/assignable-members', async (req, res) => {
  const trainerId = req.query.trainer_id
  if (!trainerId || typeof trainerId !== 'string') {
    return res.status(400).json({ error: 'trainer_id is required' })
  }

  try {
    const { data: trainer, error: trainerError } = await adminClient
      .from('profiles')
      .select('id, role')
      .eq('id', trainerId)
      .maybeSingle()
    if (trainerError) throw trainerError
    if (!trainer || trainer.role !== 'trainer') {
      return res.status(404).json({ error: 'Trainer not found' })
    }

    const [assignments, members] = await Promise.all([
      fetchAllRows(() =>
        adminClient
          .from('trainer_assignments')
          .select('member_id, trainer_id')
          .eq('status', 'active')
          .order('id'),
      ),
      fetchAllRows(() =>
        adminClient
          .from('profiles')
          .select('id, full_name, email, code')
          .eq('role', 'member')
          .order('full_name')
          .order('id'),
      ),
    ])

    const activeTrainerCounts = new Map()
    const assignedToTrainer = new Set()
    for (const assignment of assignments) {
      activeTrainerCounts.set(
        assignment.member_id,
        (activeTrainerCounts.get(assignment.member_id) ?? 0) + 1,
      )
      if (assignment.trainer_id === trainerId) {
        assignedToTrainer.add(assignment.member_id)
      }
    }

    const eligible = members
      .filter(member => !assignedToTrainer.has(member.id))
      .map(member => ({
        ...member,
        activeTrainerCount: activeTrainerCounts.get(member.id) ?? 0,
      }))
      .filter(member => member.activeTrainerCount < MEMBER_TRAINER_LIMIT)

    res.json({
      members: eligible,
      memberTrainerLimit: MEMBER_TRAINER_LIMIT,
    })
  } catch (err) {
    console.error('Assignable members error:', err)
    res.status(500).json({
      error: err?.message || 'Failed to load assignable members',
    })
  }
})

app.post('/api/assign-trainer', async (req, res) => {
  const { trainer_id, member_id } = req.body
  const memberTrainerLimitMessage = `This member already has the maximum of ${MEMBER_TRAINER_LIMIT} active trainers.`

  if (!trainer_id || !member_id) {
    return res.status(400).json({ error: 'trainer_id and member_id are required' })
  }

  try {
    const [
      { data: trainer, error: trainerError },
      { data: member, error: memberError },
      { data: activeAssignments, error: assignmentsError },
      { data: existing, error: existingError },
      { data: memberActiveAssignments, error: memberAssignmentsError },
    ] = await Promise.all([
      adminClient.from('profiles').select('id, role').eq('id', trainer_id).maybeSingle(),
      adminClient.from('profiles').select('id, role, full_name').eq('id', member_id).maybeSingle(),
      adminClient.from('trainer_assignments').select('id').eq('trainer_id', trainer_id).eq('status', 'active'),
      adminClient.from('trainer_assignments').select('id').eq('trainer_id', trainer_id).eq('member_id', member_id).eq('status', 'active').limit(1),
      adminClient.from('trainer_assignments').select('id').eq('member_id', member_id).eq('status', 'active'),
    ])
    if (trainerError) throw trainerError
    if (memberError) throw memberError
    if (assignmentsError) throw assignmentsError
    if (existingError) throw existingError
    if (memberAssignmentsError) throw memberAssignmentsError
    if (!trainer || trainer.role !== 'trainer') return res.status(404).json({ error: 'Trainer not found' })
    if (!member || member.role !== 'member') return res.status(404).json({ error: 'Member not found' })
    if ((activeAssignments ?? []).length >= 15) return res.status(409).json({ error: 'This trainer already has the maximum of 15 members.' })
    if (existing?.length) return res.status(409).json({ error: 'This member is already assigned to this trainer.' })
    if ((memberActiveAssignments ?? []).length >= MEMBER_TRAINER_LIMIT) return res.status(409).json({ error: memberTrainerLimitMessage })

    const { data, error } = await adminClient
      .from('trainer_assignments')
      .insert({ trainer_id, member_id, status: 'active' })
      .select()
      .single()

    if (error) throw error

    // Tell both people about the new assignment.
    try {
      const { data: trainerProfile } = await adminClient
        .from('profiles')
        .select('full_name, specialty, available_days')
        .eq('id', trainer_id)
        .maybeSingle()
      const trainerName = trainerProfile?.full_name || 'A trainer'
      const memberName = member.full_name || 'A new member'
      const { error: notificationError } = await adminClient.from('notifications').insert([
        {
          user_id: member_id,
          title: 'New Trainer Assigned',
          body: `${trainerName} has been assigned as your trainer. Specialty: ${trainerProfile?.specialty || 'Not specified'}. Availability: ${trainerProfile?.available_days || 'Ask your trainer for their schedule'}. You can view your trainer details in the app.`,
          sender_name: trainerName,
        },
        {
          user_id: trainer_id,
          title: 'New Member Assigned',
          body: `${memberName} has been assigned to you. You can view their details in your members list.`,
          sender_name: 'Gym Admin',
        },
      ])
      if (notificationError) throw notificationError
    } catch (notifErr) {
      // Notification failure must never roll back a successful assignment.
      console.error('Assign trainer -- notification insert failed:', notifErr?.message)
    }

    res.json({ success: true, assignment: data })
  } catch (err) {
    console.error('Assign trainer error:', err)
    if ([err?.message, err?.details, err?.hint].some(value => typeof value === 'string' && value.includes('MEMBER_TRAINER_LIMIT_REACHED'))) {
      return res.status(409).json({ error: memberTrainerLimitMessage })
    }
    res.status(err?.status || 500).json({ error: err?.message || 'Failed to assign trainer' })
  }
})

app.post('/api/unassign-trainer', async (req, res) => {
  const { assignment_id } = req.body

  if (!assignment_id) {
    return res.status(400).json({ error: 'assignment_id is required' })
  }

  try {
    const { data, error } = await adminClient
      .from('trainer_assignments')
      .update({ status: 'ended' })
      .eq('id', assignment_id)
      .select()
      .single()

    if (error) throw error
    res.json({ success: true, assignment: data })
  } catch (err) {
    console.error('Unassign trainer error:', err)
    res.status(500).json({ error: err?.message || 'Failed to unassign trainer' })
  }
})

app.post('/api/notifications/send', async (req, res) => {
  const { userId, title, body } = req.body
  if (!userId || !title || !body) return res.status(400).json({ error: 'Missing userId, title, or body' })

  try {
    const { error } = await adminClient.from('notifications').insert({
      user_id: userId,
      title,
      body,
    })
    if (error) throw error

    res.json({ success: true })
  } catch (err) {
    console.error('Send notification error:', err)
    res.status(500).json({ error: err?.message || 'Failed to send notification' })
  }
})

app.post('/api/notifications/broadcast', async (req, res) => {
  const { title, body, targetRole } = req.body
  if (!title || !body) return res.status(400).json({ error: 'Missing title or body' })

  try {
    let query = adminClient.from('profiles').select('id')
    if (targetRole && targetRole !== 'all') {
      query = query.eq('role', targetRole)
    }
    const { data: users, error: userError } = await query
    if (userError) throw userError
    if (!users || users.length === 0) return res.status(404).json({ error: 'No users found' })

    const notifications = users.map(u => ({ user_id: u.id, title, body }))
    const { error: insertError } = await adminClient.from('notifications').insert(notifications)
    if (insertError) throw insertError

    res.json({ success: true, count: users.length })
  } catch (err) {
    console.error('Broadcast error:', err)
    res.status(500).json({ error: err?.message || JSON.stringify(err) })
  }
})

app.post('/api/plans/check-daily-completions', async (req, res) => {
  const today = new Date()
  const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`

  try {
    const { data: completions, error } = await adminClient
      .from('plan_day_completions')
      .select('id, plan_id, member_id, day_number, completed_exercises, notified_member, notified_trainer, member_goal_plans!inner(exercise_plan, profiles!inner(full_name))')
      .eq('date', todayStr)
      .eq('notified_member', false)
      .eq('notified_trainer', false)

    if (error) throw error
    if (!completions || completions.length === 0) {
      return res.json({ success: true, processed: 0 })
    }

    let processed = 0
    for (const completion of completions) {
      const exercisePlan = completion.member_goal_plans?.exercise_plan || []
      const dayExercises = exercisePlan
        .filter((e) => e.day === completion.day_number)
        .map((e) => e.name || '')
      const completedExercises = completion.completed_exercises || []
      const done = dayExercises.filter((name) => completedExercises.includes(name))
      const missed = dayExercises.filter((name) => !completedExercises.includes(name))

      const memberName = completion.member_goal_plans?.profiles?.full_name || 'Member'
      const memberTitle = `Day ${completion.day_number} Complete`
      const memberBody = `You did: ${done.join(', ') || 'none'}. Missed: ${missed.join(', ') || 'none'}.`
      const trainerTitle = `${memberName} — Day ${completion.day_number} Complete`
      const trainerBody = `Done: ${done.join(', ') || 'none'}. Missed: ${missed.join(', ') || 'none'}.`

      await adminClient.from('notifications').insert([
        { user_id: completion.member_id, title: memberTitle, body: memberBody },
      ])

      const { data: plan } = await adminClient
        .from('member_goal_plans')
        .select('trainer_id')
        .eq('id', completion.plan_id)
        .single()

      if (plan?.trainer_id) {
        await adminClient.from('notifications').insert([
          { user_id: plan.trainer_id, title: trainerTitle, body: trainerBody },
        ])
      }

      await adminClient
        .from('plan_day_completions')
        .update({ notified_member: true, notified_trainer: true })
        .eq('id', completion.id)

      processed++
    }

    res.json({ success: true, processed })
  } catch (err) {
    console.error('Daily completion check error:', err)
    res.status(500).json({ error: err?.message || JSON.stringify(err) })
  }
})

app.post('/api/plans/check-weekly-completions', async (req, res) => {
  try {
    const { data: plans, error } = await adminClient
      .from('member_goal_plans')
      .select('id, member_id, trainer_id, end_date, profiles!member_id(full_name)')
      .lte('end_date', new Date().toISOString().split('T')[0])

    if (error) throw error
    if (!plans || plans.length === 0) {
      return res.json({ success: true, processed: 0 })
    }

    let processed = 0
    for (const plan of plans) {
      const { data: completions } = await adminClient
        .from('plan_day_completions')
        .select('day_number, is_complete, notified_member, notified_trainer')
        .eq('plan_id', plan.id)
        .eq('is_complete', true)

      const completedDays = (completions || []).length
      if (completedDays < 7) continue

      const alreadyNotified = (completions || []).every((c) => c.notified_member && c.notified_trainer)
      if (alreadyNotified) continue

      const memberName = plan.profiles?.full_name || 'Member'
      const memberTitle = 'Congratulations!'
      const memberBody = `You completed the 7-day plan! Great work, ${memberName}.`
      const trainerTitle = `${memberName} completed the 7-day plan`
      const trainerBody = `${memberName} finished all 7 days. View full record in Records.`

      await adminClient.from('notifications').insert([
        { user_id: plan.member_id, title: memberTitle, body: memberBody },
      ])

      if (plan.trainer_id) {
        await adminClient.from('notifications').insert([
          { user_id: plan.trainer_id, title: trainerTitle, body: trainerBody },
        ])
      }

      await adminClient
        .from('plan_day_completions')
        .update({ notified_member: true, notified_trainer: true })
        .eq('plan_id', plan.id)

      processed++
    }

    res.json({ success: true, processed })
  } catch (err) {
    console.error('Weekly completion check error:', err)
    res.status(500).json({ error: err?.message || JSON.stringify(err) })
  }
})

app.post('/api/backfill-auth', async (req, res) => {
  try {
    const { data: profiles, error } = await adminClient
      .from('profiles')
      .select('*')
      .order('created_at', { ascending: true })

    if (error) throw error
    if (!profiles || profiles.length === 0) {
      return res.json({ success: true, message: 'No profiles found', created: 0, passwordReset: 0, skipped: 0 })
    }

    const defaultPassword = process.env.DEFAULT_PASSWORD || 'Welcome123!'
    let created = 0, passwordReset = 0, skipped = 0
    const results = []

    for (const profile of profiles) {
      try {
        const { data: existingUser, error: lookupError } = await adminClient.auth.admin.getUserById(profile.id)

        if (existingUser?.user) {
          await adminClient.auth.admin.updateUserById(profile.id, { password: defaultPassword })
          results.push({ code: profile.code, email: profile.email, status: 'password_reset' })
          passwordReset++
        } else {
          const { data: authUser, error: createError } = await adminClient.auth.admin.createUser({
            email: profile.email,
            password: defaultPassword,
            email_confirm: true,
          })
          if (createError) throw createError
          await adminClient.from('profiles').update({ id: authUser.user.id }).eq('id', profile.id)
          results.push({ code: profile.code, email: profile.email, status: 'created' })
          created++
        }
      } catch (e) {
        results.push({ code: profile.code, email: profile.email, status: 'failed', error: e.message })
        skipped++
      }
    }

    res.json({
      success: true, total: profiles.length, created, passwordReset, skipped, results,
    })
  } catch (err) {
    console.error('Backfill auth error:', err)
    res.status(500).json({ error: err?.message || 'Failed to backfill auth users' })
  }
})

app.post('/api/backfill-codes', async (req, res) => {
  try {
    const { data: members, error: memberReadError } = await adminClient
      .from('profiles')
      .select('id, code, created_at')
      .eq('role', 'member')
      .order('created_at', { ascending: true })
    if (memberReadError) throw memberReadError
    const { data: trainers, error: trainerReadError } = await adminClient
      .from('profiles')
      .select('id, code, created_at')
      .eq('role', 'trainer')
      .order('created_at', { ascending: true })
    if (trainerReadError) throw trainerReadError

    const backfill = async (profiles, role) => {
      let counter = Math.max(0, ...profiles.map(profile => Number(profile.code?.match(/(\d+)$/)?.[1] ?? 0)))
      const missing = profiles.filter(item => !item.code)
      for (const profile of missing) {
        counter++
        const marker = role === 'member' ? 'M' : 'T'
        const width = 3
        const parts = new Intl.DateTimeFormat('en-CA', {
          timeZone: 'Asia/Manila', year: 'numeric', month: '2-digit',
        }).formatToParts(new Date(profile.created_at))
        const year = parts.find(part => part.type === 'year')?.value
        const month = parts.find(part => part.type === 'month')?.value
        const code = `${month}-${marker}${String(counter).padStart(width, '0')}`
        const { error } = await adminClient.from('profiles').update({ code }).eq('id', profile.id)
        if (error) throw error
      }
      return missing.length
    }

    const membersBackfilled = await backfill(members, 'member')
    const trainersBackfilled = await backfill(trainers, 'trainer')

    res.json({ success: true, membersBackfilled, trainersBackfilled })
  } catch (err) {
    console.error('Backfill error:', err)
    res.status(500).json({ error: err?.message || 'Failed to backfill codes' })
  }
})

app.post('/api/ai/predictions', async (req, res) => {
  const { member_id, days_ahead = 30 } = req.body
  if (!member_id) return res.status(400).json({ error: 'Missing member_id' })

  try {
    const response = await fetch(`${AI_SERVICE_URL}/api/ai/predictions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(req.body),
      signal: AbortSignal.timeout(8000),
    })
    if (response.ok) {
      const data = await response.json()
      // The client reads this to badge the result; without it a fallback
      // forecast was silently presented as an AI-service result.
      res.setHeader('x-forecast-source', 'ai')
      return res.json(data)
    }
    console.error('AI prediction service returned HTTP', response.status)
  } catch (e) {
    console.error('AI prediction service unavailable:', e?.cause?.code || e?.message)
  }

  res.setHeader('x-forecast-source', 'fallback')
  return createPredictionHandler(adminClient)(req, res)
})

// --- Forecast math (mirrors ai-service/services/ml.py) ----------------------
// The AI service is the primary path; this fallback runs when it is down, so it
// has to produce the same numbers or the page would contradict itself.
function getWeekNumber(d) {
  const start = new Date(d.getFullYear(), 0, 1)
  return Math.ceil((((d - start) / 86400000) + start.getDay() + 1) / 7)
}

// Production serves the built admin from this same process as the /api routes.
const adminDist = resolve(dirname(fileURLToPath(import.meta.url)), '..', 'dist')
app.use(express.static(adminDist))
app.use((req, res, next) => {
  if (req.path === '/api' || req.path.startsWith('/api/')) return next()
  res.sendFile(resolve(adminDist, 'index.html'))
})

const port = process.env.PORT || 3001
const host = process.env.API_HOST || '127.0.0.1'
app.listen(port, host, () => {
  console.log(`Admin API server running on port ${port}`)
})
