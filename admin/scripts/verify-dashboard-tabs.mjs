/**
 * Dashboard tabs verification (Task 9).
 *
 * Drives the admin dashboard end-to-end in Chromium:
 *   - signs in, sets the Jan 15 â†’ Mar 15 2026 range + Daily granularity
 *   - asserts the Daily Check-ins KPIs against service-role-computed values
 *   - asserts chart bar count, records ordering/paging, and the %-free
 *     Total Attendance summary card
 *   - visits all five tabs in dark + light + narrow viewports, screenshots
 *     each into admin/screenshots/dashboard-tabs/
 *   - fails on ANY console error / page error (the "no widget error" gate)
 *
 * Usage: node scripts/verify-dashboard-tabs.mjs [baseUrl]
 */
import { chromium } from 'playwright'
import { mkdirSync } from 'fs'
import { config } from 'dotenv'
import { createClient } from '@supabase/supabase-js'

config()
const base = (process.argv[2] ?? 'http://localhost:5173').replace(/\/$/, '')
const shots = 'screenshots/dashboard-tabs'
mkdirSync(shots, { recursive: true })

const RANGE = { start: '2026-01-15', end: '2026-03-15' }
const DAY = 86_400_000

const db = createClient(process.env.VITE_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY)

const results = []
const check = (name, ok, detail = '') => {
  results.push({ name, ok, detail })
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ` -- ${detail}` : ''}`)
}
const skip = (name, detail = '') => {
  results.push({ name, ok: null, detail })
  console.log(`SKIP  ${name}${detail ? ` -- ${detail}` : ''}`)
}

const localDay = iso => {
  const d = new Date(iso)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}
const inRange = day => day >= RANGE.start && day <= RANGE.end

async function paged(table, select, build = q => q) {
  const out = []
  for (let i = 0; i < 30; i++) {
    const from = i * 1000
    let q = db.from(table).select(select)
    q = build(q) || q
    const { data, error } = await q.range(from, from + 999)
    if (error) throw new Error(`${table}: ${error.message}`)
    out.push(...(data ?? []))
    if ((data ?? []).length < 1000) break
  }
  return out
}

/** Ground truth for the Jan 15 â†’ Mar 15 2026 window, computed with the service role. */
async function computeExpected() {
  const attendance = await paged(
    'attendance',
    'id, member_id, check_in_date, profiles!attendance_member_id_fkey(role)',
    q => q.gte('check_in_date', RANGE.start).lte('check_in_date', RANGE.end),
  )
  const trainers = attendance.filter(a => (a.profiles?.role ?? a.profiles?.[0]?.role) === 'trainer').length

  const memberships = await paged('memberships', 'id, member_id, plan_name, price, start_date, status')
  const revenueRows = memberships.filter(m => inRange(m.start_date))

  const profiles = await paged('profiles', 'id, role, created_at')
  const members = profiles.filter(p => p.role === 'member')
  const newMembers = members.filter(p => inRange(localDay(p.created_at)))

  const activeMemberIds = new Set(
    attendance.filter(a => (a.profiles?.role ?? a.profiles?.[0]?.role) !== 'trainer').map(a => a.member_id),
  )

  const days = Math.round((new Date(RANGE.end) - new Date(RANGE.start)) / DAY) + 1

  // Membership-type filter ground truth: same resolve-on-the-day rule the app uses.
  const allMemberships = await paged('memberships', 'member_id, plan_name, start_date, end_date')
  const resolvePlan = (memberId, day) => {
    const mine = allMemberships.filter(m => m.member_id === memberId)
    if (mine.length === 0) return null
    const covering = mine.find(m => m.start_date <= day && day <= m.end_date)
    return covering ? covering.plan_name : mine[mine.length - 1].plan_name
  }
  const planCount = name => attendance.filter(a => resolvePlan(a.member_id, a.check_in_date) === name).length

  return {
    checkins: attendance.length,
    dailyCheckins: planCount('Daily'),
    monthlyCheckins: planCount('Monthly'),
    trainers,
    members: attendance.length - trainers,
    avg: (attendance.length / days).toFixed(1),
    days,
    revenue: revenueRows.reduce((s, m) => s + (Number(m.price) || 0), 0),
    transactions: revenueRows.length,
    totalMembers: members.length,
    newMembers: newMembers.length,
    activeMembers: members.filter(m => activeMemberIds.has(m.id)).length,
  }
}


const TABS = [
  { id: 'checkins', label: 'Daily Check-ins', heading: 'Daily Check-ins' },
  { id: 'revenue', label: 'Revenue Overview', heading: 'Revenue Overview' },
  { id: 'growth', label: 'Member Growth', heading: 'Member Growth' },
  { id: 'members', label: 'Member Overview', heading: 'Member Overview' },
  { id: 'activity', label: 'Recent Activity', heading: 'Recent Activity' },
]

async function run() {
  const expected = await computeExpected()
  console.log('expected (service role):', expected)

  const browser = await chromium.launch()
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } })

  const consoleErrors = []
  page.on('console', msg => {
    if (msg.type() === 'error') consoleErrors.push(msg.text())
  })
  page.on('pageerror', err => consoleErrors.push(`pageerror: ${err.message}`))

  // ---- Sign in ----------------------------------------------------------
  await page.goto(`${base}/login`, { waitUntil: 'networkidle' })
  await page.locator('input[type=email]').fill('admin@fitness.com')
  await page.locator('input[type=password]').fill('Admin123!')
  await page.locator('button[type=submit]').click()
  await page.waitForURL(u => !u.pathname.includes('/login'), { timeout: 25000 })
  await page.goto(`${base}/dashboard`, { waitUntil: 'networkidle' })
  console.log(`signed in -> ${page.url()}`)

  // ---- Range + granularity ---------------------------------------------
  await setRange(page, RANGE.start, RANGE.end)
  const rangeLabel = await page.getByRole('button', { name: /Date range:/ }).first().innerText()
  check('range picker shows Jan 15 â€“ Mar 15 2026', /Jan 15, 2026/.test(rangeLabel) && /Mar 15, 2026/.test(rangeLabel), rangeLabel.trim())

  // Daily Check-ins is the default tab.
  const chart = page.locator('section[aria-label="Check-ins per period for the selected range"]')
  await chart.waitFor({ state: 'visible', timeout: 20000 })
  await setGrain(page, chart, 'Daily')

  // ---- KPI assertions ---------------------------------------------------
  const checkinsPanel = page.getByRole('tabpanel', { name: 'Daily Check-ins' })
  await page.waitForFunction(
    t => document.body.innerText.includes(t),
    String(expected.checkins),
    { timeout: 20000 },
  ).catch(() => {})

  const checks = [
    ['Total Check-ins', expected.checkins],
    ['Members', expected.members],
    ['Trainers', expected.trainers],
    ['Average per Day', Number(expected.avg)],
  ]
  for (const [title, want] of checks) {
    const ok = await waitForCardValue(page, title, want, { root: checkinsPanel })
    check(`KPI "${title}" = ${want}`, ok, `got ${await num(cardValue(page, title, checkinsPanel)).catch(() => NaN)}`)
  }

  const attendanceCard = cardText(page, 'Total Attendance')
  const attendanceText = (await attendanceCard.innerText()).trim()
  check('summary Total Attendance = range total', await num(cardValue(page, 'Total Attendance')) === expected.checkins, attendanceText.replace(/\n/g, ' | '))
  check('summary Total Attendance has no % trend', !attendanceText.includes('%'), attendanceText.replace(/\n/g, ' | '))

  // ---- Chart ------------------------------------------------------------
  let bars = await chart.locator('.recharts-bar-rectangle').count()
  
  console.log(`bars found: ${bars}`)
  check('Daily granularity renders 60 bars (60 days in range)', bars === 60, `bars=${bars}`)

  // ---- Records table ----------------------------------------------------
  const records = page.locator('section[aria-label="Records"]')
  await records.waitFor({ state: 'visible', timeout: 20000 })
  const summaryText = await records.innerText()
  const shown = /of\s+([\d,]+)\s+records/.exec(summaryText)
  check(
    'records table total = range total',
    Boolean(shown) && Number(shown[1].replace(/,/g, '')) === expected.checkins,
    shown ? shown[1] : 'summary text missing',
  )

  const dateCells = await records.locator('tbody tr td:nth-child(2)').allInnerTexts()
  const parsed = dateCells
    .map(t => (/([A-Z][a-z]{2} \d{1,2}, \d{4})/.exec(t) ?? [])[1])
    .filter(Boolean)
    .map(d => new Date(d))
  const desc = parsed.every((d, i) => i === 0 || parsed[i - 1] >= d)
  check('records sorted newest-first', desc && parsed.length > 0, parsed.map(d => d.toISOString().slice(0, 10)).join(', '))
  const within = parsed.every(d => {
    const day = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
    return day >= RANGE.start && day <= RANGE.end
  })
  check('records stay inside the selected range', within)

  // ---- Membership-type filter -------------------------------------------
  // Header filter comes before the chart in the DOM, so .first() is it even
  // when the granularity dropdown currently shows the same word.
  await page.locator('button[title="All Membership Types"]').first().click()
  await page.locator('div.glass-card.absolute button', { hasText: /^Daily$/ }).first().click()
  const dailyOk = await waitForCardValue(page, 'Total Check-ins', expected.dailyCheckins)
  check('membership filter "Daily" narrows Total Check-ins', dailyOk, `want ${expected.dailyCheckins}`)
  check(
    'Daily filter does not empty the chart',
    (await page.locator('section[aria-label="Check-ins per period for the selected range"] .recharts-bar-rectangle').count()) > 0,
  )

  await page.locator('button[title="Daily"]').first().click()
  await page.locator('div.glass-card.absolute button', { hasText: /^All Membership Types$/ }).first().click()
  const resetOk = await waitForCardValue(page, 'Total Check-ins', expected.checkins)
  check('membership filter resets to All Membership Types', resetOk, `want ${expected.checkins}`)

  await page.screenshot({ path: `${shots}/01-daily-checkins-dark.png` })

  // ---- Granularity switch is live ---------------------------------------
  await setGrain(page, chart, 'Weekly')
  let weeklyBars = await chart.locator('.recharts-bar-rectangle').count()
  
  check('weekly granularity re-buckets the chart', weeklyBars > 0 && weeklyBars < 20, `bars=${weeklyBars}`)
  await setGrain(page, chart, 'Daily')

  // ---- Remaining tabs, dark â†’ light â†’ narrow ----------------------------
  const dark = new Set(TABS.map(t => t.label))
  let shotIndex = 2

  for (const tab of TABS) {
    const tabButton = page.getByRole('tab', { name: tab.label, exact: true })
    await tabButton.click()
    const panel = page.getByRole('tabpanel', { name: tab.label })
    await panel.waitFor({ state: 'visible', timeout: 15000 })

    const heading = panel.locator('h1').first()
    check(`[${tab.label}] heading visible`, await heading.isVisible(), await heading.innerText().catch(() => ''))
    check(`[${tab.label}] renders a chart section`, (await panel.locator('section').count()) >= 2,
      `${await panel.locator('section').count()} sections`)
    check(`[${tab.label}] renders a records table`, (await panel.locator('table').count()) >= 1)

    // Per-tab value assertions against service-role ground truth.
    const want = {
      revenue: [['Total Revenue', expected.revenue], ['Total Transactions', expected.transactions]],
      growth: [['Total New Members', expected.newMembers], ['Active in Range', expected.activeMembers]],
      members: [
        ['Total Members', expected.totalMembers],
        ['Active Members', expected.activeMembers],
        ['Inactive Members', expected.totalMembers - expected.activeMembers],
      ],
      activity: [['Check-ins', expected.checkins]],
    }[tab.id] ?? []
    for (const [title, value] of want) {
      const ok = await waitForCardValue(page, title, value, { timeout: 10000, root: panel })
      check(`[${tab.label}] "${title}" = ${value}`, ok, `want ${value}`)
    }

    if (dark.has(tab.label)) {
      await page.screenshot({ path: `${shots}/${String(shotIndex).padStart(2, '0')}-${tab.id}-dark.png` })
    }
    shotIndex += 1
  }

  // Light mode pass over every tab.
  await page.getByRole('switch', { name: 'Dark mode' }).click()
  await page.waitForTimeout(400)
  for (const tab of TABS) {
    await page.getByRole('tab', { name: tab.label, exact: true }).click()
    const panel = page.getByRole('tabpanel', { name: tab.label })
    await panel.waitFor({ state: 'visible', timeout: 15000 })
    await page.waitForTimeout(350)
    await page.screenshot({ path: `${shots}/light-${tab.id}.png` })
  }
  await page.getByRole('switch', { name: 'Dark mode' }).click()
  await page.waitForTimeout(400)

  // Narrow viewport pass.
  await page.setViewportSize({ width: 1100, height: 900 })
  for (const tab of TABS) {
    await page.getByRole('tab', { name: tab.label, exact: true }).click()
    const panel = page.getByRole('tabpanel', { name: tab.label })
    await panel.waitFor({ state: 'visible', timeout: 15000 })
    await page.waitForTimeout(350)
    await page.screenshot({ path: `${shots}/narrow-${tab.id}.png` })
  }
  await page.setViewportSize({ width: 1920, height: 1080 })

  // ---- Tab keyboard navigation -----------------------------------------
  await page.getByRole('tab', { name: 'Daily Check-ins', exact: true }).focus()
  await page.keyboard.press('ArrowRight')
  const selected = await page.getByRole('tab', { selected: true }).innerText()
  check('arrow keys move the tab selection', selected.includes('Revenue Overview'), selected)
  await page.keyboard.press('Home')

  await browser.close()

  // ---- Console gate -----------------------------------------------------
  const uniqueErrors = [...new Set(consoleErrors)]
  check('zero console/page errors across the whole run', uniqueErrors.length === 0, uniqueErrors.slice(0, 5).join(' || '))

  const failed = results.filter(r => r.ok === false)
  const skipped = results.filter(r => r.ok === null)
  console.log('\n================ RESULT ================')
  console.log(`${results.filter(r => r.ok === true).length} passed, ${failed.length} failed, ${skipped.length} skipped`)
  console.log(failed.length === 0
    ? 'RESULT: PASS'
    : `RESULT: FAIL\n${failed.map(f => ` - ${f.name} (${f.detail})`).join('\n')}`)
  console.log(`screenshots -> ${shots}/`)
  process.exit(failed.length === 0 ? 0 : 1)
}

run().catch(err => {
  console.error('verification crashed:', err)
  process.exit(1)
})

const num = async locator => {
  const text = (await locator.first().innerText()).trim()
  const n = Number(text.replace(/[^0-9.]/g, ''))
  return Number.isFinite(n) ? n : NaN
}

/**
 * Value <p> (index 1: title, value, sub) inside a KPI/Stats card.
 * `root` scopes the search — pass the active tabpanel whenever the title also
 * exists in the summary row (e.g. "Total Revenue", "Total Members").
 */
const cardValue = (page, title, root = page) =>
  root
    .locator('div.glass-card')
    .filter({ has: page.locator(`p:text-is("${title}")`) })
    .first()
    .locator('div.min-w-0 > p')
    .nth(1)

/** Waits until a card's numeric value equals `want` (data refetch is async). */
async function waitForCardValue(page, title, want, { timeout = 15000, root } = {}) {
  const deadline = Date.now() + timeout
  let last = NaN
  while (Date.now() < deadline) {
    last = await num(cardValue(page, title, root)).catch(() => NaN)
    if (last === want) return true
    await page.waitForTimeout(250)
  }
  console.log(`  (timeout waiting for "${title}" = ${want}, last=${last})`)
  return false
}

/** Whole card text (for trend/% checks). */
const cardText = (page, title, root = page) =>
  root
    .locator('div.glass-card')
    .filter({ has: page.locator(`p:text-is("${title}")`) })
    .first()

async function setRange(page, start, end) {
  await page.getByRole('button', { name: /Date range:/ }).first().click()
  const dialog = page.getByRole('dialog', { name: 'Choose a date range' })
  await dialog.waitFor({ state: 'visible' })
  await dialog.locator('input[type=date]').first().fill(start)
  await dialog.locator('input[type=date]').nth(1).fill(end)
  await dialog.getByRole('button', { name: 'Apply range' }).click()
  await dialog.waitFor({ state: 'hidden' })
}

/** Opens the chart's granularity dropdown and picks a label. */
async function setGrain(page, chart, label) {
  const trigger = chart.getByRole('button', { name: /^(Daily|Weekly|Monthly)$/ })
  await trigger.click()
  await chart
    .locator('div.glass-card.absolute button', { hasText: new RegExp(`^${label}$`) })
    .first()
    .click()
  await page.waitForTimeout(500)
}

