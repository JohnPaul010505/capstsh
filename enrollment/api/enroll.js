import { createClient } from '@supabase/supabase-js'

const MAX_LENGTH = {
  fullName: 120,
  email: 254,
  phone: 24,
  address: 500,
  emergencyContactName: 120,
  emergencyContactPhone: 24,
}

function text(value) {
  return typeof value === 'string' ? value.trim() : ''
}

function isValidPhone(value) {
  return !value || /^\d{1,11}$/.test(value)
}

const HEALTH_QUESTIONS = [
  'illnessOrHeartProblem',
  'recentDoctorVisit',
  'movementDifficulty',
  'jointBackShoulderLegInjury',
]
const HEALTH_CHOICES = new Set(['yes', 'no', 'other'])

function validateHealthBackground(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false
  return HEALTH_QUESTIONS.every((key) => {
    const answer = value[key]
    if (!answer || typeof answer !== 'object' || !HEALTH_CHOICES.has(answer.choice)) return false
    return answer.choice !== 'other' || (typeof answer.details === 'string' && answer.details.trim().length > 0 && answer.details.length <= 500)
  })
}

function reply(res, status, body) {
  res.setHeader('Cache-Control', 'no-store')
  return res.status(status).json(body)
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST')
    return reply(res, 405, { error: 'Method not allowed' })
  }

  const contentLength = Number(req.headers['content-length'] || 0)
  if (contentLength > 20_000) return reply(res, 413, { error: 'Application is too large' })
  if (!req.headers['content-type']?.includes('application/json')) {
    return reply(res, 415, { error: 'Expected a JSON request' })
  }

  const origin = req.headers.origin
  const host = req.headers['x-forwarded-host'] || req.headers.host
  const protocol = req.headers['x-forwarded-proto'] || 'https'
  if (origin && host && origin !== `${protocol}://${host}`) {
    return reply(res, 403, { error: 'Request origin is not allowed' })
  }

  const body = req.body && typeof req.body === 'object' ? req.body : {}
  // Silently accept automated honeypot submissions so bots don't learn the field.
  if (text(body.website)) return reply(res, 201, { success: true })

  const fullName = text(body.fullName)
  const email = text(body.email).toLowerCase()
  const phone = text(body.phone)
  const dateOfBirth = text(body.dateOfBirth)
  const gender = text(body.gender)
  const civilStatus = text(body.civilStatus)
  const religion = text(body.religion)
  const religionOther = text(body.religionOther)
  const address = text(body.address)
  const emergencyContactName = text(body.emergencyContactName)
  const emergencyContactPhone = text(body.emergencyContactPhone)
  const healthBackground = body.healthBackground

  if (!fullName || !email) return reply(res, 400, { error: 'Full name and email are required.' })
  if (fullName.length > MAX_LENGTH.fullName || email.length > MAX_LENGTH.email ||
      phone.length > MAX_LENGTH.phone || address.length > MAX_LENGTH.address ||
      emergencyContactName.length > MAX_LENGTH.emergencyContactName ||
      emergencyContactPhone.length > MAX_LENGTH.emergencyContactPhone) {
    return reply(res, 400, { error: 'One or more fields are too long.' })
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return reply(res, 400, { error: 'Enter a valid email address.' })
  if (!isValidPhone(phone) || !isValidPhone(emergencyContactPhone)) {
    return reply(res, 400, { error: 'Phone numbers can contain a maximum of 11 digits.' })
  }
  if (civilStatus && !['single', 'married'].includes(civilStatus)) {
    return reply(res, 400, { error: 'Select a valid civil status.' })
  }
  if (religion && !['roman_catholic', 'christian', 'iglesia_ni_cristo', 'islam', 'other'].includes(religion)) {
    return reply(res, 400, { error: 'Select a valid religion.' })
  }
  if (religion === 'other' && !religionOther) return reply(res, 400, { error: 'Enter your religion.' })
  if (religionOther.length > 120) return reply(res, 400, { error: 'Religion is too long.' })
  if (!validateHealthBackground(healthBackground)) {
    return reply(res, 400, { error: 'Please answer all health screening questions.' })
  }
  if (dateOfBirth && !/^\d{4}-\d{2}-\d{2}$/.test(dateOfBirth)) {
    return reply(res, 400, { error: 'Enter a valid date of birth.' })
  }
  if (gender && !['male', 'female', 'prefer_not_to_say'].includes(gender)) {
    return reply(res, 400, { error: 'Select a valid gender option.' })
  }

  const supabaseUrl = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!supabaseUrl || !serviceRoleKey) {
    console.error('Enrollment API is missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY')
    return reply(res, 500, { error: 'Enrollment is temporarily unavailable. Please try again later.' })
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  try {
    const { error } = await adminClient.from('enrollments').insert({
      full_name: fullName,
      email,
      phone: phone || null,
      date_of_birth: dateOfBirth || null,
      gender: gender || null,
      civil_status: civilStatus || null,
      religion: religion || null,
      religion_other: religion === 'other' ? religionOther : null,
      address: address || null,
      emergency_contact_name: emergencyContactName || null,
      emergency_contact_phone: emergencyContactPhone || null,
      health_background: healthBackground,
      status: 'pending',
    })

    if (error) {
      console.error('Enrollment insert failed:', {
        code: error.code,
        message: error.message,
        details: error.details,
        hint: error.hint,
      })
      return reply(res, 500, { error: 'We could not save your application. Please try again.' })
    }
  } catch (error) {
    console.error('Enrollment request failed:', error instanceof Error ? error.message : 'Unknown Supabase request error')
    return reply(res, 500, { error: 'We could not save your application. Please try again.' })
  }

  return reply(res, 201, { success: true })
}
