import { client } from './seed/lib/common.mjs'

// Identified demo accounts only. Keep manually created trainers untouched.
const demoTrainers = [
  { code: '2023-02-T003', email: 'trainer1@mock.fit', specialty: 'Strength Training', available_days: 'Mon 09:00-17:00, Wed 09:00-17:00, Fri 09:00-15:00' },
  { code: '2023-02-T004', email: 'trainer2@mock.fit', specialty: 'Weight Loss', available_days: 'Tue 08:00-16:00, Thu 08:00-16:00, Sat 09:00-13:00' },
  { code: '2023-03-T005', email: 'trainer3@mock.fit', specialty: 'Cardio', available_days: 'Mon 10:00-18:00, Wed 10:00-18:00, Sat 08:00-12:00' },
  { code: '2023-03-T006', email: 'trainer4@mock.fit', specialty: 'Functional Training', available_days: 'Tue 09:00-17:00, Thu 09:00-17:00, Fri 09:00-15:00' },
]

const { data: profiles, error } = await client.from('profiles')
  .select('id, code, email, specialty, available_days')
  .eq('role', 'trainer')
  .in('code', demoTrainers.map(trainer => trainer.code))
if (error) throw error

let updated = 0
for (const demo of demoTrainers) {
  const profile = profiles?.find(row => row.code === demo.code && row.email === demo.email)
  if (!profile) throw new Error(`Expected mock trainer ${demo.code} (${demo.email}) was not found`)
  const patch = {
    specialty: profile.specialty || demo.specialty,
    available_days: profile.available_days || demo.available_days,
  }
  if (patch.specialty === profile.specialty && patch.available_days === profile.available_days) continue
  const { error: updateError } = await client.from('profiles').update(patch).eq('id', profile.id).eq('email', demo.email)
  if (updateError) throw updateError
  updated++
}

const { data: verified, error: verifyError } = await client.from('profiles')
  .select('code, email, specialty, available_days')
  .in('code', demoTrainers.map(trainer => trainer.code))
if (verifyError) throw verifyError
for (const demo of demoTrainers) {
  const actual = verified?.find(row => row.code === demo.code && row.email === demo.email)
  if (!actual?.specialty || !actual.available_days) throw new Error(`Mock trainer ${demo.code} is missing details`)
}
console.log(`Verified ${demoTrainers.length} mock trainers; updated ${updated}.`)
