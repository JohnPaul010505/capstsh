import { config } from 'dotenv'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
config({ path: resolve(dirname(fileURLToPath(import.meta.url)), '..', '.env') })
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.VITE_SUPABASE_URL
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY
if (!supabaseUrl || !serviceRoleKey) {
  console.error('Missing VITE_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in admin/.env')
  process.exit(1)
}
const client = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
})

const AUG6_START = '2026-08-06T00:00:00+08:00'
const AUG6_END = '2026-08-07T00:00:00+08:00'

async function main() {
  const { data: profile } = await client
    .from('profiles')
    .select('id, full_name, code')
    .eq('code', 'M002')
    .maybeSingle()
  if (!profile) {
    console.error('M002 not found')
    process.exit(1)
  }
  const memberId = profile.id
  console.log('Cleaning Aug 6 storage for M002 (' + profile.full_name + ', ' + memberId + ')...')

  const { data: logs, error } = await client
    .from('workout_logs')
    .select('id, proof_url, logged_at')
    .eq('member_id', memberId)
    .gte('logged_at', AUG6_START)
    .lt('logged_at', AUG6_END)

  if (error) {
    console.error('fetch error', error)
    process.exit(1)
  }

  console.log('Aug6 workout_logs:', logs.length)
  const urls = (logs || []).map((l) => l.proof_url).filter(Boolean)
  console.log('proof_urls:', JSON.stringify(urls, null, 2))

  const paths = urls
    .map((u) => {
      try {
        const uu = new URL(u)
        return uu.pathname.replace(/^\/+/, '')
      } catch {
        return u
      }
    })
    .filter(Boolean)

  console.log('storage paths:', JSON.stringify(paths, null, 2))
  if (paths.length) {
    const { data: storage, error: sErr } = await client.storage
      .from('proofs')
      .remove(paths)
    console.log('storage remove', storage, sErr)
  } else {
    console.log('no proof urls to remove')
  }
}
main().catch((e) => {
  console.error('Cleanup failed:', e)
  process.exit(1)
})
