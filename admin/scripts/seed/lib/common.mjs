import { config } from 'dotenv'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
import fs from 'node:fs'
import { createClient } from '@supabase/supabase-js'

const __dirname = dirname(fileURLToPath(import.meta.url))
// lib/ -> seed/ -> scripts/ -> admin/.env
config({ path: resolve(__dirname, '..', '..', '..', '.env') })

const supabaseUrl = process.env.VITE_SUPABASE_URL
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY
if (!supabaseUrl || !serviceRoleKey) {
  console.error('Missing VITE_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in admin/.env')
  process.exit(1)
}

export const client = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
})

export const SEED_DIR = resolve(__dirname, '..', 'data')

// ---- Deterministic PRNG ----
export function mulberry32(seed) {
  return function () {
    seed |= 0; seed = (seed + 0x6D2B79F5) | 0
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

export function makeRand(seed) {
  const f = mulberry32(seed)
  const randInt = (min, max) => Math.floor(f() * (max - min + 1)) + min
  const pick = (arr) => arr[Math.floor(f() * arr.length)]
  const shuffle = (arr) => {
    const a = [...arr]
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(f() * (i + 1))
      ;[a[i], a[j]] = [a[j], a[i]]
    }
    return a
  }
  return { rand: f, randInt, pick, shuffle }
}

// ---- Deterministic UUID (valid v4 format) ----
export const uuid = (prefix, n) =>
  `${prefix}-0000-4000-8000-${n.toString(16).padStart(12, '0')}`

// ---- Local (PH, UTC+8) time helpers ----
// localIso renders an instant's Manila wall-clock as an ISO string and
// localDate its Asia/Manila civil date. Use localDate for date columns and
// date math only — timestamp columns store REAL UTC instants (the app writes
// new Date().toISOString()), so never persist localIso() output directly.
export const PH_OFFSET = 8 * 60 * 60 * 1000
export const localIso = (d) => new Date(d.getTime() + PH_OFFSET).toISOString()
export const localDate = (d) => localIso(d).split('T')[0]

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

export const chunk = (arr, size) => {
  const out = []
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size))
  return out
}

export async function upsertChunks(table, rows, onConflict = 'id', size = 400) {
  for (const c of chunk(rows, size)) {
    const { error } = await client.from(table).upsert(c, { onConflict, ignoreDuplicates: true })
    if (error) throw new Error(`${table}: ${error.message}`)
  }
}

export async function insertChunks(table, rows, size = 400) {
  for (const c of chunk(rows, size)) {
    const { error } = await client.from(table).insert(c)
    if (error) throw new Error(`${table}: ${error.message}`)
  }
}

// ---- Manifest persistence (resume support) ----
export function manifestPath(name) {
  return resolve(SEED_DIR, name)
}

export function readManifest(name) {
  const p = manifestPath(name)
  if (!fs.existsSync(p)) return null
  return JSON.parse(fs.readFileSync(p, 'utf8'))
}

export function writeManifest(name, obj) {
  const p = manifestPath(name)
  fs.mkdirSync(SEED_DIR, { recursive: true })
  const tmp = `${p}.tmp`
  fs.writeFileSync(tmp, JSON.stringify(obj, null, 2), 'utf8')
  fs.renameSync(tmp, p)
}

// ---- Minimal CLI arg parser: --key value / --flag ----
export function parseArgs(argv) {
  const args = {}
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (!a.startsWith('--')) continue
    const key = a.slice(2)
    const next = argv[i + 1]
    if (next && !next.startsWith('--')) {
      args[key] = next
      i++
    } else {
      args[key] = true
    }
  }
  return args
}
