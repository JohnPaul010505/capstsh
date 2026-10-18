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
  return !value || value.replace(/\D/g, '').length === 11
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
  const address = text(body.address)
  const emergencyContactName = text(body.emergencyContactName)
  const emergencyContactPhone = text(body.emergencyContactPhone)

  if (!fullName || !email) return reply(res, 400, { error: 'Full name and email are required.' })
  if (fullName.length > MAX_LENGTH.fullName || email.length > MAX_LENGTH.email ||
      phone.length > MAX_LENGTH.phone || address.length > MAX_LENGTH.address ||
      emergencyContactName.length > MAX_LENGTH.emergencyContactName ||
      emergencyContactPhone.length > MAX_LENGTH.emergencyContactPhone) {
    return reply(res, 400, { error: 'One or more fields are too long.' })
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return reply(res, 400, { error: 'Enter a valid email address.' })
  if (!isValidPhone(phone) || !isValidPhone(emergencyContactPhone)) {
    return reply(res, 400, { error: 'Phone numbers must contain exactly 11 digits.' })
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

  const { error } = await adminClient.from('enrollments').insert({
    full_name: fullName,
    email,
    phone: phone || null,
    date_of_birth: dateOfBirth || null,
    gender: gender || null,
    address: address || null,
    emergency_contact_name: emergencyContactName || null,
    emergency_contact_phone: emergencyContactPhone || null,
    status: 'pending',
  })

  if (error) {
    console.error('Enrollment insert failed:', error.message)
    return reply(res, 500, { error: 'We could not save your application. Please try again.' })
  }

  return reply(res, 201, { success: true })
}
