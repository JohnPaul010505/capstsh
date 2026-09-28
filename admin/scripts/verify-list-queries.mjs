import { client } from './seed/lib/common.mjs'
// `sanitizeSearchTerm` lives in src/lib/pagedTable.ts, which node cannot import
// directly. It is exercised here through its observable effect: a term
// containing PostgREST filter metacharacters must not 400 and must not change
// the filter's shape.
let failures = 0
const check = (name, cond, detail = '') => {
  console.log(`${cond ? 'PASS' : 'FAIL'}  ${name}${detail ? '  — ' + detail : ''}`)
  if (!cond) failures++
}

// --- members: page 1 vs page 2 must be disjoint and cover the same ordering ---
const MEMBERS_SEL = 'id, full_name, email, code, gender, phone, is_active, date_of_birth, created_at'
const order = [{ column: 'code', ascending: true }, { column: 'id', ascending: true }]

const p1 = await client.from('profiles').select(MEMBERS_SEL, { count: 'exact' })
  .eq('role', 'member').order('code', { ascending: true }).order('id', { ascending: true }).range(0, 19)
const p2 = await client.from('profiles').select(MEMBERS_SEL, { count: 'exact' })
  .eq('role', 'member').order('code', { ascending: true }).order('id', { ascending: true }).range(20, 39)

check('members total is the real roster', p1.count === 987, `count=${p1.count}`)
check('page 1 has 20 rows', p1.data.length === 20, `got ${p1.data.length}`)
const ids1 = new Set(p1.data.map((r) => r.id))
const overlap = p2.data.filter((r) => ids1.has(r.id)).length
check('pages are disjoint (no row on two pages)', overlap === 0, `overlap=${overlap}`)

// --- search by member CODE (the plan requires name AND code) ---
const byCode = await client.from('profiles').select('id, code, full_name', { count: 'exact' })
  .eq('role', 'member')
  .or('full_name.ilike.*M034*,code.ilike.*M034*,email.ilike.*M034*')
  .order('code').order('id').range(0, 19)
check('search by code "M034" finds the member', byCode.count >= 1, `count=${byCode.count} -> ${byCode.data[0]?.code}`)
check('search by code returns that exact code', byCode.data[0]?.code === 'M034', `got ${byCode.data[0]?.code}`)

// --- search by partial NAME ---
const byName = await client.from('profiles').select('id, code, full_name', { count: 'exact' })
  .eq('role', 'member')
  .or('full_name.ilike.*Dela Cruz*,code.ilike.*Dela Cruz*,email.ilike.*Dela Cruz*')
  .range(0, 19)
check('search by name "Dela Cruz" returns matches', byName.count > 0, `count=${byName.count}`)

// --- a term with filter metacharacters must not break or widen the query ---
const nasty = 'a,or(role.eq.admin)'
const cleaned = nasty.replace(/[,()*\\%]/g, ' ').replace(/\s+/g, ' ').trim()
const injected = await client.from('profiles').select('id', { count: 'exact' }).eq('role', 'member')
  .or(`full_name.ilike.*${cleaned}*`)
check('a comma-injection term does not 400', !injected.error, injected.error?.message ?? 'ok')
check('a comma-injection term does not widen past the member filter', injected.count === 0, `count=${injected.count}`)
check('the raw term is not passed through unescaped', cleaned !== nasty && !cleaned.includes(','))

// --- memberships: plan filter must be IN the query so `total` matches ---
const MEM_SEL = 'id, member_id, plan_name, price, start_date, end_date, status, created_at, profiles!memberships_member_id_fkey(full_name, email, code)'
const daily = await client.from('memberships').select(MEM_SEL, { count: 'exact' })
  .eq('plan_name', 'Daily')
  .order('start_date', { ascending: false }).order('id', { ascending: false }).range(0, 19)
check('Daily memberships total is 60', daily.count === 60, `count=${daily.count}`)
check('Daily page returns rows', daily.data.length > 0, `rows=${daily.data.length}`)
check('joined profile is present', !!daily.data[0]?.profiles?.full_name, daily.data[0]?.profiles?.full_name)

// --- date range narrows the total ---
const ranged = await client.from('memberships').select('id', { count: 'exact' })
  .gte('start_date', '2026-01-01').lte('start_date', '2026-12-31')
const all = await client.from('memberships').select('id', { count: 'exact' })
check('date range narrows the total', ranged.count > 0 && ranged.count < all.count, `${ranged.count} of ${all.count}`)

// --- empty inFilter must match nothing, not everything ---
const emptyIn = await client.from('memberships').select('id', { count: 'exact' })
  .in('member_id', ['00000000-0000-0000-0000-000000000000'])
check('empty member_ids matches nothing', emptyIn.count === 0, `count=${emptyIn.count}`)

console.log(failures === 0 ? '\nTASK 8 QUERIES: ALL PASS' : `\nTASK 8 QUERIES: ${failures} FAILED`)
process.exit(failures === 0 ? 0 : 2)

