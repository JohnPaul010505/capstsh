import { createClient } from '@supabase/supabase-js'
import { randomUUID } from 'node:crypto'

function getAdminClient() {
  const url = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!url || !key) throw new Error('Admin enrollment API is missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.')
  return createClient(url, key, { auth: { autoRefreshToken: false, persistSession: false } })
}

async function requireAdmin(req, client) {
  const match = req.headers.authorization?.match(/^Bearer\s+(.+)$/i)
  if (!match) return null
  const { data, error } = await client.auth.getUser(match[1])
  if (error || !data.user) return null
  const { data: profile, error: profileError } = await client
    .from('profiles').select('role').eq('id', data.user.id).maybeSingle()
  if (profileError || profile?.role !== 'admin') return null
  return data.user
}

function reply(res, status, body) {
  res.setHeader('Cache-Control', 'no-store')
  return res.status(status).json(body)
}

export async function confirmEnrollment(req, res) {
  if (req.method !== 'POST') return reply(res, 405, { error: 'Method not allowed' })
  let client
  try {
    client = getAdminClient()
    const admin = await requireAdmin(req, client)
    if (!admin) return reply(res, 401, { error: 'Admin sign-in is required.' })
    const enrollmentId = req.body?.enrollmentId
    if (!enrollmentId) return reply(res, 400, { error: 'Missing enrollment id.' })

    const { data: enrollment, error: readError } = await client.from('enrollments')
      .select('*').eq('id', enrollmentId).maybeSingle()
    if (readError) throw readError
    if (!enrollment) return reply(res, 404, { error: 'Enrollment was not found.' })
    if (!['pending', 'confirmed'].includes(enrollment.status)) {
      return reply(res, 409, { error: 'Only pending applications can be confirmed.' })
    }

    let userId = enrollment.auth_user_id
    let legacyPassword = null
    if (!userId) {
      legacyPassword = `${randomUUID()}aA1!`
      const { data: created, error } = await client.auth.admin.createUser({
        email: enrollment.email, password: legacyPassword, email_confirm: true,
        ban_duration: '876000h', user_metadata: { full_name: enrollment.full_name },
      })
      if (error) throw error
      userId = created.user.id
      const { error: linkError } = await client.from('enrollments')
        .update({ auth_user_id: userId }).eq('id', enrollment.id)
      if (linkError) throw linkError
    }

    const profileData = {
      id: userId, role: 'member', full_name: enrollment.full_name, email: enrollment.email,
      phone: enrollment.phone || null, date_of_birth: enrollment.date_of_birth || null,
      gender: enrollment.gender || null, civil_status: enrollment.civil_status || null,
      religion: enrollment.religion || null, religion_other: enrollment.religion === 'other' ? enrollment.religion_other || null : null,
      address: enrollment.address || null, emergency_contact_name: enrollment.emergency_contact_name || null,
      emergency_contact_phone: enrollment.emergency_contact_phone || null,
    }
    const { data: profile, error: profileError } = await client.from('profiles')
      .upsert(profileData, { onConflict: 'id' }).select('code').single()
    if (profileError) throw profileError

    if (enrollment.health_background && Object.keys(enrollment.health_background).length) {
      const { error } = await client.from('member_health_background').upsert({
        member_id: userId, answers: enrollment.health_background, updated_at: new Date().toISOString(),
      }, { onConflict: 'member_id' })
      if (error) throw error
    }

    const { error: unlockError } = await client.auth.admin.updateUserById(userId, { ban_duration: 'none', email_confirm: true })
    if (unlockError) throw unlockError

    const { error: enrollmentError } = await client.from('enrollments').update({
      status: 'confirmed', confirmed_at: new Date().toISOString(), confirmed_by: admin.id,
    }).eq('id', enrollment.id)
    if (enrollmentError) throw enrollmentError
    return reply(res, 200, { success: true, code: profile.code, legacyPassword })
  } catch (error) {
    console.error('Confirm enrollment failed:', error instanceof Error ? error.message : 'Unknown error')
    return reply(res, 500, { error: 'Could not confirm this application. Please retry or inspect the server log.' })
  }
}

export async function rejectEnrollment(req, res) {
  if (req.method !== 'POST') return reply(res, 405, { error: 'Method not allowed' })
  try {
    const client = getAdminClient()
    const admin = await requireAdmin(req, client)
    if (!admin) return reply(res, 401, { error: 'Admin sign-in is required.' })
    const enrollmentId = req.body?.enrollmentId
    if (!enrollmentId) return reply(res, 400, { error: 'Missing enrollment id.' })
    const { data: enrollment, error: readError } = await client.from('enrollments')
      .select('id, status, auth_user_id').eq('id', enrollmentId).maybeSingle()
    if (readError) throw readError
    if (!enrollment) return reply(res, 404, { error: 'Enrollment was not found.' })
    if (enrollment.status !== 'pending') return reply(res, 409, { error: 'Only pending applications can be rejected.' })
    const { error } = await client.from('enrollments').update({ status: 'rejected' }).eq('id', enrollment.id)
    if (error) throw error
    if (enrollment.auth_user_id) {
      const { error: deleteError } = await client.auth.admin.deleteUser(enrollment.auth_user_id)
      if (deleteError) console.error('Rejected applicant Auth cleanup failed:', deleteError.message)
    }
    return reply(res, 200, { success: true })
  } catch (error) {
    console.error('Reject enrollment failed:', error instanceof Error ? error.message : 'Unknown error')
    return reply(res, 500, { error: 'Could not reject this application. Please retry.' })
  }
}
