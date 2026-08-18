import { config } from 'dotenv'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
config({ path: resolve(dirname(fileURLToPath(import.meta.url)), '..', '.env') })
import express from 'express'
import cors from 'cors'
import { createClient } from '@supabase/supabase-js'

const app = express()
app.use(cors({ origin: ['http://localhost:5173', 'http://localhost:3000'], credentials: true }))
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

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', routes: ['enroll', 'users', 'delete-user', 'assign-trainer', 'unassign-trainer', 'backfill-auth', 'backfill-codes', 'ai/predictions'] })
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
    const response = await fetch(`http://localhost:8000/api/ai/predictions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(req.body),
      signal: AbortSignal.timeout(8000),
    })
    if (response.ok) {
      const data = await response.json()
      return res.json(data)
    }
  } catch (e) {
    /* AI service not running — use inline fallback */
  }

  const results = []

  const { data: measurements } = await adminClient
    .from('body_measurements')
    .select('weight_kg, body_fat_pct, measured_at')
    .eq('member_id', member_id)
    .order('measured_at', { ascending: true })

  if (measurements && measurements.length > 1) {
    const weights = measurements.map(m => m.weight_kg).filter(Boolean)
    if (weights.length > 1) {
      const pred = simpleTrend(weights, days_ahead)
      results.push({
        prediction_type: 'weight', current_value: weights[weights.length - 1],
        predicted_value: pred.value, unit: 'kg',
        days_ahead, confidence: pred.confidence,
      })
    }
    const bfs = measurements.map(m => m.body_fat_pct).filter(Boolean)
    if (bfs.length > 1) {
      const pred = simpleTrend(bfs, days_ahead)
      results.push({
        prediction_type: 'body_fat', current_value: bfs[bfs.length - 1],
        predicted_value: pred.value, unit: '%',
        days_ahead, confidence: pred.confidence,
      })
    }
  }

  const { data: attendance } = await adminClient
    .from('attendance')
    .select('check_in_time')
    .eq('member_id', member_id)
    .order('check_in_time', { ascending: false })
    .limit(30)

  if (attendance && attendance.length > 0) {
    const weekCounts = {}
    for (const a of attendance) {
      const d = new Date(a.check_in_time)
      const wk = `${d.getFullYear()}-W${String(getWeekNumber(d)).padStart(2, '0')}`
      weekCounts[wk] = (weekCounts[wk] || 0) + 1
    }
    const rates = Object.values(weekCounts).map(c => Math.min(1, c / 7))
    const last = new Date(attendance[0].check_in_time)
    const daysSince = Math.floor((Date.now() - last.getTime()) / 86400000)
    const avgRate = rates.reduce((a, b) => a + b, 0) / rates.length
    const riskScore = Math.max(0, Math.min(1, 1 - (avgRate * 0.6 + Math.min(1, daysSince / 30) * 0.4)))
    results.push({
      prediction_type: 'retention_risk', current_value: Math.round(avgRate * 100) / 100,
      predicted_value: Math.round(riskScore * 100) / 100, unit: 'score (0-1)',
      days_ahead: 30, confidence: Math.round((1 - riskScore) * 100) / 100,
    })
  }

  if (results.length === 0) {
    return res.status(404).json({ detail: 'Not enough data for predictions. Log measurements and attendance first.' })
  }

  res.json(results)
})

function simpleTrend(values, steps) {
  const n = values.length
  const xMean = (n - 1) / 2
  const yMean = values.reduce((a, b) => a + b, 0) / n
  let num = 0, den = 0
  for (let i = 0; i < n; i++) {
    const dx = i - xMean
    num += dx * (values[i] - yMean)
    den += dx * dx
  }
  const slope = den !== 0 ? num / den : 0
  const predicted = values[n - 1] + slope * steps
  const ssRes = values.reduce((a, v) => a + (v - (yMean + slope * (values.indexOf(v) - xMean))) ** 2, 0)
  const ssTot = values.reduce((a, v) => a + (v - yMean) ** 2, 0)
  const r2 = ssTot !== 0 ? Math.max(0, Math.min(1, 1 - ssRes / ssTot)) : 0
  return { value: Math.round(predicted * 100) / 100, confidence: Math.round(r2 * 100) / 100 }
}

function getWeekNumber(d) {
  const start = new Date(d.getFullYear(), 0, 1)
  return Math.ceil((((d - start) / 86400000) + start.getDay() + 1) / 7)
}

const port = process.env.PORT || 3001
app.listen(port, () => {
  console.log(`Admin API server running on port ${port}`)
})
