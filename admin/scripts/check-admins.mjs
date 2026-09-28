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
    if (m) env[m[1].trim()] = m[2].trim().replace(/^['"]|['"]$/g, '')
  }
  return env
}

const env = loadEnv()
const s = createClient(env.VITE_SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

const { data: { users }, error } = await s.auth.admin.listUsers()
if (error) {
  console.error('Error:', error)
  process.exit(1)
}

console.log('Total users:', users.length)
const admins = users.filter(u => u.email?.includes('admin'))
console.log('Admins in auth.users:')
for (const a of admins) {
  console.log(`- ${a.id}: ${a.email}`)
}
