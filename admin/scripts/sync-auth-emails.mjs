#!/usr/bin/env node
/**
 * Reconcile profiles.email with auth.users.email.
 *
 * The mobile app resolves a member/trainer by code, then calls
 * signInWithPassword(profiles.email, password). An admin edit that only
 * updates `profiles` leaves `auth.users` on the old address, so login fails
 * with "Invalid login credentials" (the app surfaces that as "Wrong password").
 *
 * Usage: node scripts/sync-auth-emails.mjs [--dry-run]
 * Safe to re-run: rows already in sync are skipped. `profiles.email` is the
 * source of truth here — it is what the login lookup reads.
 */
import { config } from 'dotenv'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
import { createClient } from '@supabase/supabase-js'

config({ path: resolve(dirname(fileURLToPath(import.meta.url)), '..', '.env') })

const dryRun = process.argv.includes('--dry-run')

const s = createClient(process.env.VITE_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

// Paginate both sides fully: listUsers and PostgREST both cap at 1000 rows,
// and the first audit pass silently missed mismatches past that cap.
const authById = new Map()
for (let page = 1; ; page++) {
  const { data, error } = await s.auth.admin.listUsers({ page, perPage: 1000 })
  if (error) throw error
  data.users.forEach(u => authById.set(u.id, u))
  if (data.users.length < 1000) break
}

const profiles = []
for (let from = 0; ; from += 1000) {
  const { data, error } = await s.from('profiles').select('id, code, email, role').range(from, from + 999)
  if (error) throw error
  profiles.push(...data)
  if (data.length < 1000) break
}

let synced = 0
let failed = 0
let noEmail = 0
let noAuth = 0

for (const p of profiles) {
  const authUser = authById.get(p.id)
  if (!authUser) {
    // Creating auth users is /api/backfill-auth's job — report only.
    noAuth++
    console.log(`NO-AUTH  ${p.code} (${p.role}) ${p.email ?? '-'}`)
    continue
  }
  if (!p.email) {
    // No address to sync; a profile with no email cannot log in by email.
    noEmail++
    console.log(`NO-EMAIL  ${p.code} (${p.role}) auth=${authUser.email ?? '(none)'}`)
    continue
  }
  if ((authUser.email ?? '').toLowerCase() === p.email.toLowerCase()) continue

  console.log(`${dryRun ? 'DRY ' : 'SYNC'}    ${p.code}  auth=${authUser.email ?? '(none)'}  ->  profiles=${p.email}`)
  if (dryRun) continue

  const { error } = await s.auth.admin.updateUserById(p.id, { email: p.email, email_confirm: true })
  if (error) {
    failed++
    console.log(`  FAILED: ${error.message}`)
    continue
  }
  synced++
}

console.log(
  `\n${profiles.length} profiles | ${synced} synced | ${failed} failed | ` +
  `${noAuth} without auth user | ${noEmail} without email${dryRun ? ' (dry run)' : ''}`,
)
