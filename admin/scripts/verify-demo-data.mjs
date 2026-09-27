import { createClient } from '@supabase/supabase-js'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const envPath = path.resolve(__dirname, '../.env')

function loadEnv() {
  const content = fs.readFileSync(envPath, 'utf8')
  const env = {}
  for (const line of content.split(/\r?\n/)) {
    const m = line.match(/^\s*([^#=]+)=(.*)$/)
    if (m) {
      env[m[1].trim()] = m[2].trim().replace(/^['"]|['"]$/g, '')
    }
  }
  return env
}

const env = loadEnv()
const supabaseUrl = env.VITE_SUPABASE_URL
const serviceRoleKey = env.SUPABASE_SERVICE_ROLE_KEY

if (!supabaseUrl || !serviceRoleKey) {
  console.error('Missing VITE_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in admin/.env')
  process.exit(1)
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
})

async function getCount(table, filter = null) {
  let q = supabase.from(table).select('*', { count: 'exact', head: true })
  if (filter) {
    q = filter(q)
  }
  const { count, error } = await q
  if (error) throw new Error(`${table} count failed: ${error.message}`)
  return count ?? 0
}

async function run() {
  console.log('=== VERIFY DEMO DATA / DB GROUND TRUTH ===')
  console.log(`Supabase URL: ${supabaseUrl}`)

  const totalMembers = await getCount('profiles', q => q.eq('role', 'member'))
  const totalTrainers = await getCount('profiles', q => q.eq('role', 'trainer'))
  const totalAdmins = await getCount('profiles', q => q.eq('role', 'admin'))
  const totalProfiles = await getCount('profiles')

  const totalAttendance = await getCount('attendance')
  const totalMemberships = await getCount('memberships')
  const totalAssignments = await getCount('trainer_assignments')
  const totalFeedback = await getCount('trainer_feedback')
  const totalPredictions = await getCount('predictions')
  const totalNotifications = await getCount('notifications')
  
  const pendingEnrollments = await getCount('enrollments', q => q.eq('status', 'pending'))
  const confirmedEnrollments = await getCount('enrollments', q => q.eq('status', 'confirmed'))
  const totalEnrollments = await getCount('enrollments')

  const pendingRenewals = await getCount('membership_renewal_requests', q => q.eq('status', 'pending'))
  const totalRenewals = await getCount('membership_renewal_requests')

  // Min and max attendance dates
  const { data: firstAtt } = await supabase.from('attendance').select('check_in_date').order('check_in_date', { ascending: true }).limit(1)
  const { data: lastAtt } = await supabase.from('attendance').select('check_in_date').order('check_in_date', { ascending: false }).limit(1)

  const groundTruth = {
    timestamp: new Date().toISOString(),
    profiles: {
      total: totalProfiles,
      members: totalMembers,
      trainers: totalTrainers,
      admins: totalAdmins,
    },
    attendance: {
      total: totalAttendance,
      minDate: firstAtt?.[0]?.check_in_date ?? null,
      maxDate: lastAtt?.[0]?.check_in_date ?? null,
    },
    memberships: {
      total: totalMemberships,
    },
    trainer_assignments: totalAssignments,
    trainer_feedback: totalFeedback,
    predictions: totalPredictions,
    notifications: totalNotifications,
    enrollments: {
      total: totalEnrollments,
      pending: pendingEnrollments,
      confirmed: confirmedEnrollments,
    },
    membership_renewal_requests: {
      total: totalRenewals,
      pending: pendingRenewals,
    },
  }

  console.table({
    'Profiles (Total)': groundTruth.profiles.total,
    'Members': groundTruth.profiles.members,
    'Trainers': groundTruth.profiles.trainers,
    'Admins': groundTruth.profiles.admins,
    'Attendance': groundTruth.attendance.total,
    'Attendance Min Date': groundTruth.attendance.minDate,
    'Attendance Max Date': groundTruth.attendance.maxDate,
    'Memberships': groundTruth.memberships.total,
    'Trainer Assignments': groundTruth.trainer_assignments,
    'Trainer Feedback': groundTruth.trainer_feedback,
    'Predictions': groundTruth.predictions,
    'Notifications': groundTruth.notifications,
    'Enrollments (Pending / Total)': `${groundTruth.enrollments.pending} / ${groundTruth.enrollments.total}`,
    'Renewals (Pending / Total)': `${groundTruth.membership_renewal_requests.pending} / ${groundTruth.membership_renewal_requests.total}`,
  })

  const outPath = path.resolve(__dirname, '../screenshots/demo-data/ground-truth.json')
  fs.writeFileSync(outPath, JSON.stringify(groundTruth, null, 2), 'utf8')
  console.log(`Saved ground truth to: ${outPath}`)

  return groundTruth
}

run().catch(err => {
  console.error(err)
  process.exit(1)
})
