import { config } from 'dotenv'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
config({ path: resolve(dirname(fileURLToPath(import.meta.url)), '..', '.env') })
import express from 'express'
import cors from 'cors'
import { createClient } from '@supabase/supabase-js'

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

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', routes: ['enroll', 'users', 'delete-user', 'assign-trainer', 'unassign-trainer', 'backfill-auth', 'backfill-codes', 'ai/predictions', 'plans/check-daily-completions', 'plans/check-weekly-completions'] })
})

app.post('/api/enroll', async (req, res) => {
  const { fullName, email, phone, dateOfBirth, gender, address, emergencyContactName, emergencyContactPhone } = req.body
  if (!fullName || !email) return res.status(400).json({ error: 'Name and email are required' })
  try {
    const { error } = await adminClient.from('enrollments').insert({
      full_name: fullName, email, phone: phone || null,
      date_of_birth: dateOfBirth || null, gender: gender || null,
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
  const { email, password, fullName, role, phone, dateOfBirth, gender, address, emergencyContactName, emergencyContactPhone, specialty, availableDays } = req.body

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

app.post('/api/confirm-enrollment', async (req, res) => {
  const { enrollment, confirmedBy } = req.body
  if (!enrollment?.id) return res.status(400).json({ error: 'Missing enrollment data' })

  try {
    const tempPassword = Math.random().toString(36).slice(-10) + 'A1!'

    const { data: authUser, error: authError } = await adminClient.auth.admin.createUser({
      email: enrollment.email,
      password: tempPassword,
      email_confirm: true,
      user_metadata: { full_name: enrollment.full_name },
    })
    if (authError) throw authError

    const { error: updateError } = await adminClient
      .from('enrollments')
      .update({ status: 'confirmed', confirmed_at: new Date().toISOString(), confirmed_by: confirmedBy })
      .eq('id', enrollment.id)
    if (updateError) throw updateError

    const { data: profile, error: profileError } = await adminClient
      .from('profiles')
      .insert({
        id: authUser.user.id,
        role: 'member',
        full_name: enrollment.full_name,
        email: enrollment.email,
        phone: enrollment.phone || null,
        date_of_birth: enrollment.date_of_birth || null,
        gender: enrollment.gender || null,
        emergency_contact_name: enrollment.emergency_contact_name || null,
        emergency_contact_phone: enrollment.emergency_contact_phone || null,
      })
      .select('code')
      .single()
    if (profileError) throw profileError

    res.json({ success: true, code: profile.code, tempPassword })
  } catch (err) {
    console.error('Confirm enrollment error:', err)
    res.status(500).json({ error: err?.message || 'Failed to confirm enrollment' })
  }
})

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

app.post('/api/assign-trainer', async (req, res) => {
  const { trainer_id, member_id } = req.body

  if (!trainer_id || !member_id) {
    return res.status(400).json({ error: 'trainer_id and member_id are required' })
  }

  try {
    // End any other active assignment for this member first, so exactly one
    // active row per member survives. Old rows stay for history.
    const { error: endError } = await adminClient
      .from('trainer_assignments')
      .update({ status: 'ended', ended_at: new Date().toISOString() })
      .eq('member_id', member_id)
      .eq('status', 'active')
    if (endError) throw endError

    const { data, error } = await adminClient
      .from('trainer_assignments')
      .insert({ trainer_id, member_id, status: 'active' })
      .select()
      .single()

    if (error) throw error
    res.json({ success: true, assignment: data })
  } catch (err) {
    console.error('Assign trainer error:', err)
    res.status(500).json({ error: err?.message || 'Failed to assign trainer' })
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
    let mCounter = 1
    const { data: members } = await adminClient
      .from('profiles')
      .select('id')
      .eq('role', 'member')
      .is('code', null)
      .order('created_at', { ascending: true })

    for (const m of members) {
      const code = `M${String(mCounter).padStart(3, '0')}`
      await adminClient.from('profiles').update({ code }).eq('id', m.id)
      mCounter++
    }

    let tCounter = 1
    const { data: trainers } = await adminClient
      .from('profiles')
      .select('id')
      .eq('role', 'trainer')
      .is('code', null)
      .order('created_at', { ascending: true })

    for (const t of trainers) {
      const code = `T${String(tCounter).padStart(3, '0')}`
      await adminClient.from('profiles').update({ code }).eq('id', t.id)
      tCounter++
    }

    res.json({ success: true, membersBackfilled: members.length, trainersBackfilled: trainers.length })
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
  } catch (e) {
    /* AI service not running — use inline fallback */
  }

  // Everything below is the offline fallback: same maths, same guardrails, but
  // nothing is persisted (the client badges it "not persisted").
  res.setHeader('x-forecast-source', 'fallback')
  const results = []
  const notes = []

  const { data: measurements } = await adminClient
    .from('body_measurements')
    .select('weight_kg, measured_at')
    .eq('member_id', member_id)
    .order('measured_at', { ascending: true })

  if (measurements && measurements.length) {
    const weights = measurements.map((m) => m.weight_kg)
    if (weights.some((v) => v !== null && v !== undefined)) {
      // Weight only, matching the AI service: body fat is not forecast because
      // no screen in the system captures it.
      const pred = forecastTrend(weights, measurements.map((m) => m.measured_at), days_ahead)
      if (!pred.sufficient) {
        notes.push(`Weight: ${pred.reason}`)
      } else {
        results.push({
          prediction_type: 'weight',
          current_value: pred.current_value,
          predicted_value: pred.predicted_value,
          unit: 'kg',
          days_ahead,
          confidence: pred.confidence,
          data_points: pred.data_points,
          span_days: pred.span_days,
          date_from: pred.date_from,
          date_to: pred.date_to,
          daily_rate: pred.daily_rate,
          change: pred.change,
          clamped: pred.clamped,
          method: pred.method,
        })
      }
    }
  }

  const { data: attendance } = await adminClient
    .from('attendance')
    .select('check_in_time')
    .eq('member_id', member_id)
    .order('check_in_time', { ascending: false })
    .limit(30)

  if (attendance && attendance.length > 0) {
    // Chronological order by earliest check-in: week numbers restart in January,
    // so sorting by week number would read the "is attendance falling?" trend
    // backwards across a year boundary.
    const weekStats = new Map()
    for (const a of attendance) {
      const d = new Date(a.check_in_time)
      const key = getWeekNumber(d)
      const slot = weekStats.get(key)
      if (!slot) weekStats.set(key, { count: 1, first: d })
      else {
        slot.count += 1
        if (d < slot.first) slot.first = d
      }
    }
    const ordered = [...weekStats.values()].sort((a, b) => a.first - b.first)
    const rates = ordered.map((s) => Math.min(1, s.count / 7))
    const last = new Date(attendance[0].check_in_time)
    const daysSince = Math.floor((Date.now() - last.getTime()) / 86400000)
    const risk = retentionForecast(rates, daysSince)
    results.push({
      prediction_type: 'retention_risk',
      current_value: Math.round(rates[rates.length - 1] * 100) / 100,
      predicted_value: risk.score,
      unit: 'risk score (0-1)',
      days_ahead: 30,
      // Trust in the estimate (attendance history depth) — not the risk score,
      // which used to render "high risk" as "high confidence".
      confidence: risk.confidence,
      data_points: rates.length,
      daily_rate: risk.weekly_rate,
      method: 'weighted-heuristic',
      note:
        `60% check-in frequency + 20% falling trend + 20% recency ` +
        `(last visit ${daysSince}d ago) - risk level ${risk.risk}`,
    })
  }

  if (results.length === 0) {
    return res.status(404).json({
      detail: 'Not enough data for predictions. ' + (notes.length ? notes.join(' ') : 'Log measurements and attendance first.'),
    })
  }

  res.json(results)
})

// --- Forecast math (mirrors ai-service/services/ml.py) ----------------------
// The AI service is the primary path; this fallback runs when it is down, so it
// has to produce the same numbers or the page would contradict itself.
const MIN_POINTS = 3
const MIN_SPAN_DAYS = 7
const FULL_SAMPLE_POINTS = 5
const FULL_SAMPLE_DAYS = 28
const MAX_CONFIDENCE = 0.95 // a forecast is never reported as certain
const MAX_WEIGHT_CHANGE_PCT = 0.05
const MIN_PLAUSIBLE_VALUE = 0.5
const RETENTION_FULL_WEEKS = 6
const RETENTION_W_FREQUENCY = 0.6
const RETENTION_W_TREND = 0.2
const RETENTION_W_RECENCY = 0.2

const round2 = (v) => Math.round(v * 100) / 100
const round4 = (v) => Math.round(v * 10000) / 10000

function toDayNumber(stamp) {
  if (stamp === null || stamp === undefined) return null
  const t = stamp instanceof Date ? stamp.getTime() : new Date(stamp).getTime()
  return Number.isNaN(t) ? null : t / 86400000
}

/// Least-squares trend over *elapsed days* (not row indices), clamped to a
/// physiologically plausible rate, and only forecast once there is enough
/// history to mean anything.
function forecastTrend(values, stamps, daysAhead) {
  const points = []
  values.forEach((raw, i) => {
    const v = typeof raw === 'number' ? raw : parseFloat(raw)
    if (!Number.isFinite(v) || v <= 0) return
    const stamp = stamps && i < stamps.length ? stamps[i] : null
    points.push({ value: v, day: toDayNumber(stamp), stamp })
  })
  if (points.length === 0) {
    return { sufficient: false, reason: 'no measurements recorded yet', data_points: 0, current_value: 0 }
  }
  const useDates = points.length >= 2 && points.every((p) => p.day !== null)
  if (useDates) points.sort((a, b) => a.day - b.day)
  const ys = points.map((p) => p.value)
  const xs = points.map((p, i) => (useDates ? p.day : i))
  const n = ys.length
  const current = ys[n - 1]
  const spanDays = useDates ? xs[n - 1] - xs[0] : 0
  const basis = {
    current_value: round2(current),
    data_points: n,
    span_days: Math.round(spanDays),
    date_from: points[0].stamp ?? null,
    date_to: points[n - 1].stamp ?? null,
    method: 'ols-linear-regression',
  }
  if (n < 2) {
    return { ...basis, sufficient: false, reason: `only ${n} measurement logged - at least 2 are needed` }
  }
  if (n < MIN_POINTS || (useDates && spanDays < MIN_SPAN_DAYS)) {
    return {
      ...basis,
      sufficient: false,
      reason: `needs at least ${MIN_POINTS} weigh-ins over ${MIN_SPAN_DAYS}+ days (has ${n} over ${Math.round(spanDays)}d)`,
    }
  }
  const xMean = xs.reduce((a, b) => a + b, 0) / n
  const yMean = ys.reduce((a, b) => a + b, 0) / n
  let num = 0
  let den = 0
  for (let i = 0; i < n; i++) {
    const dx = xs[i] - xMean
    num += dx * (ys[i] - yMean)
    den += dx * dx
  }
  const slope = den !== 0 ? num / den : 0
  const intercept = yMean - slope * xMean
  let ssRes = 0
  let ssTot = 0
  for (let i = 0; i < n; i++) {
    const fit = intercept + slope * xs[i]
    ssRes += (ys[i] - fit) ** 2
    ssTot += (ys[i] - yMean) ** 2
  }
  const r2 = ssTot !== 0 ? Math.max(0, Math.min(1, 1 - ssRes / ssTot)) : 0
  const rawPrediction = intercept + slope * (xs[n - 1] + daysAhead)
  // Body weight may move at most +/-5% in the horizon: the clinical safe rate is
  // roughly 0.5-1% of body weight per week.
  const low = Math.max(current * (1 - MAX_WEIGHT_CHANGE_PCT), MIN_PLAUSIBLE_VALUE)
  const high = current * (1 + MAX_WEIGHT_CHANGE_PCT)
  const predicted = Math.min(Math.max(rawPrediction, low), high)
  const sampleFactor = Math.min(1, (n - 1) / (FULL_SAMPLE_POINTS - 1))
  const spanFactor = useDates ? Math.min(1, spanDays / FULL_SAMPLE_DAYS) : 0.5
  return {
    ...basis,
    sufficient: true,
    predicted_value: round2(predicted),
    change: round2(predicted - current),
    clamped: Math.abs(predicted - rawPrediction) > 1e-9,
    confidence: round2(Math.max(0, Math.min(MAX_CONFIDENCE, r2 * sampleFactor * spanFactor))),
    r2: Math.round(r2 * 1000) / 1000,
    trend: slope > 0 ? 'up' : slope < 0 ? 'down' : 'flat',
    daily_rate: useDates ? round4(slope) : null,
  }
}

/// Mirrors retention_risk(): frequency credit minus falling trend minus recency.
function retentionForecast(rates, daysSince) {
  if (!rates.length) return { score: 0.5, confidence: 0, risk: 'unknown', weekly_rate: null, data_points: 0 }
  const avg = rates.reduce((a, b) => a + b, 0) / rates.length
  let trend = 0
  if (rates.length > 1) {
    const xMean = (rates.length - 1) / 2
    let num = 0
    let den = 0
    for (let i = 0; i < rates.length; i++) {
      const dx = i - xMean
      num += dx * (rates[i] - avg)
      den += dx * dx
    }
    trend = den !== 0 ? num / den : 0
  }
  const raw = 1 - (
    avg * RETENTION_W_FREQUENCY
    + Math.max(0, -trend) * RETENTION_W_TREND
    + Math.min(1, daysSince / 30) * RETENTION_W_RECENCY
  )
  // Round before banding: classifying the raw value labelled a 0.4004 risk as
  // "medium" for a perfectly consistent attendee.
  const score = round2(Math.max(0, Math.min(1, raw)))
  return {
    score,
    confidence: round2(Math.max(0.3, Math.min(1, rates.length / RETENTION_FULL_WEEKS))),
    risk: score > 0.7 ? 'high' : score > 0.4 ? 'medium' : 'low',
    weekly_rate: Math.round(avg * 1000) / 1000,
    data_points: rates.length,
  }
}

function getWeekNumber(d) {
  const start = new Date(d.getFullYear(), 0, 1)
  return Math.ceil((((d - start) / 86400000) + start.getDay() + 1) / 7)
}

const port = process.env.PORT || 3001
app.listen(port, () => {
  console.log(`Admin API server running on port ${port}`)
})
