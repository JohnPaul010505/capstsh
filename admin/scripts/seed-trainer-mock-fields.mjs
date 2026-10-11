import { client } from './seed/lib/common.mjs'

const specialties = ['Strength Training', 'Weight Loss', 'Yoga', 'Pilates', 'Cardio', 'Functional Training']
const schedules = ['Mon,Wed,Fri', 'Tue,Thu,Sat', 'Mon,Tue,Thu', 'Wed,Fri,Sat']

const { data: trainers, error } = await client
  .from('profiles')
  .select('id, code, specialty, available_days, email')
  .eq('role', 'trainer')
  .or('email.ilike.%@demo.fit,email.ilike.%@mock.ft')
  .order('code')
if (error) throw error

let updated = 0
for (const [index, trainer] of (trainers ?? []).entries()) {
  const ordinal = Number(trainer.code?.match(/(\d+)$/)?.[1] ?? index + 1)
  const patch = {
    specialty: trainer.specialty || specialties[(ordinal - 1) % specialties.length],
    available_days: trainer.available_days || schedules[(ordinal - 1) % schedules.length],
  }
  if (patch.specialty === trainer.specialty && patch.available_days === trainer.available_days) continue
  const { error: updateError } = await client.from('profiles').update(patch).eq('id', trainer.id)
  if (updateError) throw updateError
  updated++
}
console.log(`Checked ${trainers?.length ?? 0} mock trainers; updated ${updated}.`)
