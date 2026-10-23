import { config } from 'dotenv'
import { createClient } from '@supabase/supabase-js'
config({ quiet: true })
const db = createClient(process.env.VITE_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY)
const { data: member, error } = await db.from('profiles').select('id').eq('code', '2023-01-M002').single()
if (error) throw error
const { data, error: queryError } = await db.from('meal_logs').select('id, food_name, meal_time, calories').eq('member_id', member.id).gte('meal_time', '2026-10-22T00:00:00Z').lt('meal_time', '2026-10-24T00:00:00Z').order('meal_time')
if (queryError) throw queryError
console.log(JSON.stringify(data, null, 2))
if (process.argv.includes('--repair')) {
  const expected = new Map([
    ['f6b2355f-91c1-4753-8084-ab0c931168bb', '2026-10-22T23:33:23.412308+00:00'],
    ['1896fa89-c39d-4e5d-920f-101d71bc0f8e', '2026-10-22T23:34:23.052923+00:00'],
  ])
  for (const row of data) {
    if (expected.get(row.id) !== row.meal_time) continue
    const corrected = new Date(Date.parse(row.meal_time) - 8 * 3600000).toISOString()
    const { data: saved, error } = await db.from('meal_logs').update({ meal_time: corrected }).eq('id', row.id).eq('member_id', member.id).eq('meal_time', row.meal_time).select('id, meal_time')
    if (error) throw error
    console.log('Corrected October 22 meal:', saved)
  }
}
