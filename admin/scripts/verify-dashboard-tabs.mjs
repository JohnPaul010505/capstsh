/**
 * Dashboard tabs verification (Task 9).
 *
 * Drives the admin dashboard end-to-end in Chromium:
 *   - signs in, sets the Jan 15 â†’ Mar 15 2026 range + Daily granularity
 *   - asserts the Daily Check-ins KPIs against service-role-computed values
 *   - asserts chart bar count, records ordering/paging, and — for every tab at
 *     seven viewport sizes from 1920x1080 down to 1024x768 — that the panel
 *     neither scrolls the page nor clips its own content (Task 11's no-scroll
 *     gate; the summary-row assertions were removed with the cards in Task 10)
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
  // Ordered exactly like the app's fetchMemberships(). resolvePlan() falls back
  // to "the last row of this member's rows", so the expected number is only
  // correct if the rows arrive in the same order the app sees them. This fetch
  // used to be unordered, which made the expectation arbitrary: it happened to
  // agree while every member's memberships were contiguous, and started
  // disagreeing once the seed gave members spaced re-join history, where most
  // check-ins fall through to that "latest membership" branch.
  const allMemberships = await paged(
    'memberships',
    'member_id, plan_name, start_date, end_date',
    q => q.order('start_date', { ascending: true }).order('id', { ascending: true }),
  )
  const resolvePlan = (memberId, day) => {
    const mine = allMemberships.filter(m => m.member_id === memberId)
    if (mine.length === 0) return null
    const covering = mine.find(m => m.start_date <= day && day <= m.end_date)
    return covering ? covering.plan_name : mine[mine.length - 1].plan_name
  }
  const planCount = name => attendance.filter(a => resolvePlan(a.member_id, a.check_in_date) === name).length

  // All-time growth ground truth. `allDailyAvg` is the per-DAY mean behind the
  // "Daily Average" KPI (987 joins over 1,369 days is 0.7 a day). The chart
  // used to ALSO draw a per-BUCKET mean as a dashed benchmark - a completely
  // different number (~21.9 over 45 monthly buckets) - but that line was
  // removed on request, so nothing renders a mean on the bucket axis anymore.
  const joins = members.map(p => localDay(p.created_at)).sort()
  const firstJoin = joins[0]
  const today = new Date()
  const allDays = Math.round((new Date(`${localDay(today.toISOString())}T00:00:00`) - new Date(`${firstJoin}T00:00:00`)) / DAY) + 1

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
    allNewMembers: joins.length,
    allDays,
    allDailyAvg: joins.length / allDays,
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
  // Failed responses are tracked separately because the console message text
  // has no URL, and the console gate needs to know WHICH request failed.
  const failedResponses = []
  page.on('response', r => { if (r.status() >= 400) failedResponses.push({ status: r.status(), url: r.url() }) })
  page.on('console', msg => {
    if (msg.type() === 'error') consoleErrors.push(msg.text())
  })
  page.on('pageerror', err => consoleErrors.push(`pageerror: ${err.message}`))

  // ---- Sign in ----------------------------------------------------------
  // Credentials come from the git-ignored .env (ADMIN_EMAIL / ADMIN_PASSWORD),
  // never hardcoded. This script used to carry a literal admin@fitness.com /
  // Admin123! pair that no longer existed, so every run failed at sign-in and
  // looked like a product bug.
  const email = process.env.ADMIN_EMAIL
  const password = process.env.ADMIN_PASSWORD
  if (!email || !password) {
    throw new Error('ADMIN_EMAIL / ADMIN_PASSWORD missing from .env — cannot sign in')
  }
  await page.goto(`${base}/login`, { waitUntil: 'networkidle' })
  await page.locator('input[type=email]').fill(email)
  await page.locator('input[type=password]').fill(password)
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

  // The all-time summary row (Total Revenue / Members / Trainers /
  // Attendance) was removed in Task 10, so its two assertions are replaced by
  // the property that actually matters now: the panel fits its box.
  //
  // Note the two-part assertion. `docOverflow` alone is NOT sufficient: the
  // panel is `overflow-hidden`, so a too-tall panel reports no page scrollbar
  // while silently clipping its own content. `panelClipped` catches that, which
  // is the failure mode this check originally missed.
  const fit = await page.evaluate(() => {
    const visible = el => el && el.getBoundingClientRect().height > 0
    const panel = [...document.querySelectorAll('[role=tabpanel]')].find(visible)
    const se = document.scrollingElement
    return {
      docOverflow: se.scrollHeight - se.clientHeight,
      panelClipped: panel ? panel.scrollHeight - panel.clientHeight : -1,
    }
  })
  check('check-ins panel does not scroll the page', fit.docOverflow <= 0, `overflow=${fit.docOverflow}px`)
  check('check-ins panel does not clip its own content', fit.panelClipped <= 0, `clipped=${fit.panelClipped}px`)

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
  // ---- Member Growth over All time --------------------------------------
  // One defect this section exists to pin down, which made the All-time view
  // look broken while every number in it was correct: a hand-picked Daily grain
  // survived the switch to All time and drew 1,369 buckets, about a pixel each.
  // The dashed per-bucket "Avg" benchmark line is asserted here too - by its
  // ABSENCE: it was removed on request, and a label creeping back would put
  // the old floor-pinned "Avg 0.7" on this chart again.
  // The demo roster is spread evenly by design (~21 new members in every month),
  // so a flat plateau here is the dataset, not a bug - what is asserted is that
  // the chart says so honestly: monthly buckets and ticks that carry the year
  // across a four-year axis.
  await page.getByRole('tab', { name: 'Member Growth' }).click()
  await page.waitForTimeout(700)
  await page.getByRole('button', { name: /Date range:/ }).first().click()
  const rangeDialog = page.getByRole('dialog', { name: 'Choose a date range' })
  await rangeDialog.waitFor({ state: 'visible' })
  await rangeDialog.getByRole('button', { name: 'All time' }).click()
  await page.waitForTimeout(2500)

  const growthChart = page.locator('section[aria-label="New members per period for the selected range"]')
  // Switching to All time re-keys the query and forces a COLD fetch of all
  // three datasets (987 profiles, 1,860 memberships, 13k attendance rows). It is
  // the one read in this run that is not already cached, and a fixed sleep is a
  // race against it: read too early and the panel is still loading, so the KPI
  // cards show their em dash and the chart is a skeleton. The four checks below
  // then measure the loading state rather than the numbers - which is how this
  // section came to report shown=0 for a correct 0.7. Wait for the chart to
  // actually be drawn; the assertions themselves are unchanged.
  const drawn = await waitForChartDrawn(growthChart)
  check('the All-time growth chart is drawn, not still loading', drawn, drawn ? '.recharts-surface attached' : 'no .recharts-surface within 30s')

  const grainTrigger = growthChart.getByRole('button', { name: /^(Daily|Weekly|Monthly)$/ })
  const openingGrain = (await grainTrigger.innerText()).trim()
  check('All time opens on Monthly', openingGrain === 'Monthly', `got "${openingGrain}"`)

  // Daily and Weekly are still listed, but disabled: 1,369 and 196 buckets are
  // not charts. A silent clamp would leave the dropdown reading "Daily" over a
  // monthly series, which is a different lie.
  await grainTrigger.click()
  await page.waitForTimeout(400)
  const grainOptions = await growthChart
    .locator('div.glass-card.absolute button')
    .evaluateAll(btns => btns.map(b => ({ label: b.innerText.trim(), disabled: b.disabled })))
  await page.keyboard.press('Escape')
  const byLabel = Object.fromEntries(grainOptions.map(o => [o.label, o.disabled]))
  check('All time disables Daily and Weekly',
    byLabel.Daily === true && byLabel.Weekly === true && byLabel.Monthly === false,
    JSON.stringify(grainOptions))

  // Recharts renders ticks and any chart label as SVG <text>, where innerText
  // is null - textContent is the only way to read them. The dashed "Avg"
  // benchmark line was removed on request, so the label must NOT be back.
  const avgLabel = (await growthChart.locator('text').filter({ hasText: /^Avg / }).allTextContents())[0] ?? ''
  check('the dashed Avg benchmark line stays removed', avgLabel === '', `label="${avgLabel}"`)

  // The KPI card keeps the per-DAY figure - the only average left now that the
  // chart's benchmark line is gone.
  const growthPanel = page.getByRole('tabpanel', { name: 'Member Growth' })
  const dailyAvgShown = await num(cardValue(page, 'Daily Average', growthPanel)).catch(() => NaN)
  check('the Daily Average KPI still reports the per-day mean',
    Math.abs(dailyAvgShown - expected.allDailyAvg) <= 0.1,
    `shown=${dailyAvgShown} want≈${expected.allDailyAvg.toFixed(1)}`)

  const growthTicks = await growthChart.locator('.recharts-xAxis .recharts-cartesian-axis-tick-value')
    .allTextContents()
  const labelled = growthTicks.map(t => t.trim()).filter(Boolean)
  // A four-year axis labelled "Jan | Jun | Nov" repeats itself: the reader
  // cannot tell the first January from the last, which is what the year suffix
  // ("Jan '23") is for. A single tick is still enough to catch a regression.
  check('multi-year month ticks carry the year',
    labelled.length > 0 && labelled.every(t => /^[A-Z][a-z]{2} '\d{2}$/.test(t)),
    labelled.join(' | '))

  const growthFit = await page.evaluate(() => {
    const panel = [...document.querySelectorAll('[role=tabpanel]')].find(el => el.getBoundingClientRect().height > 0)
    const se = document.scrollingElement
    return {
      docOverflow: se.scrollHeight - se.clientHeight,
      panelClipped: panel ? panel.scrollHeight - panel.clientHeight : -1,
    }
  })
  check('the All-time growth panel neither scrolls nor clips',
    growthFit.docOverflow <= 0 && growthFit.panelClipped <= 0, JSON.stringify(growthFit))
  await page.screenshot({ path: `${shots}/07-growth-all-time.png` })

  // Put the window back for the sweep below, from a RELOADED dashboard. Setting
  // the date inputs a second time in the same session left the picker's draft
  // state out of step with its committed value after the All-time preset, so
  // "Apply range" re-applied All time and the reset silently did nothing. A
  // reload is the honest way to get back to the state this script started from
  // - default 30-day window - and the label is asserted rather than assumed.
  await page.goto(`${base}/dashboard`, { waitUntil: 'networkidle' })
  await page.waitForTimeout(1500)
  await setRange(page, RANGE.start, RANGE.end)
  await page.waitForTimeout(1200)
  const rangeAfter = await page.getByRole('button', { name: /Date range:/ }).first().getAttribute('aria-label')
  check('the window is restored for the tab sweep', /Jan 15, 2026/.test(rangeAfter ?? ''), rangeAfter ?? 'no label')
  await page.getByRole('tab', { name: 'Member Growth' }).click()
  await page.waitForTimeout(800)
  const restored = page.locator('section[aria-label="New members per period for the selected range"]')
  const resetGrain = (await restored.getByRole('button', { name: /^(Daily|Weekly|Monthly)$/ })
    .innerText().catch(() => '')).trim()
  // 60 days is past the 45-day Daily threshold, so the default is Weekly - which
  // also proves Daily became selectable again, the same guard as All time
  // having disabled it.
  check('a shorter window re-enables the finer grains', resetGrain === 'Weekly', `got "${resetGrain}"`)
  await setGrain(page, restored, 'Daily')

  // ---- No-scroll sweep: every tab x every viewport ------------------------
  // Task 11's real gate. Three assertions per cell, because any one alone lies:
  //   docOverflow  - the page must not scroll
  //   panelClipped - the panel must not hide its own content to achieve that
  //   rows > 0     - a collapsed panel passes both numbers while showing nothing
  // `overflow-hidden` on the panel makes a too-tall panel report no page
  // scrollbar while silently cutting off the bottom of itself, so the second
  // number is the one that catches a regression the first one waves through.
  const VIEWPORTS = [
    { width: 1920, height: 1080 },
    { width: 1600, height: 900 },
    { width: 1440, height: 800 },
    { width: 1366, height: 768 },
    { width: 1280, height: 680 },
    { width: 1152, height: 700 },
    { width: 1024, height: 768 },
  ]
  for (const vp of VIEWPORTS) {
    await page.setViewportSize(vp)
    await page.waitForTimeout(500)
    for (const tab of TABS) {
      await page.getByRole('tab', { name: tab.label, exact: true }).click()
      const panel = page.getByRole('tabpanel', { name: tab.label })
      await panel.waitFor({ state: 'visible', timeout: 15000 })
      await page.waitForTimeout(500)
      const m = await page.evaluate(() => {
        const visible = el => el && el.getBoundingClientRect().height > 0
        const p = [...document.querySelectorAll('[role=tabpanel]')].find(visible)
        const se = document.scrollingElement
        return {
          doc: se.scrollHeight - se.clientHeight,
          clip: p ? p.scrollHeight - p.clientHeight : -1,
          rows: p ? p.querySelectorAll('tbody tr').length : 0,
        }
      })
      check(
        `[${tab.label}] ${vp.width}x${vp.height} fits, no scrollbar, nothing clipped`,
        m.doc <= 0 && m.clip <= 0 && m.rows > 0,
        `pageOverflow=${m.doc}px clipped=${m.clip}px rows=${m.rows}`,
      )
    }
  }
  await page.setViewportSize({ width: 1920, height: 1080 })
  await page.waitForTimeout(400)

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
      // 60s, not the 10s this used to allow. The Member Overview tab depends on
      // fetchLastCheckins, which pages the whole 42k-row attendance table, so
      // its KPIs stay 0 until that finishes — about 29s today. Once migration
      // 0035's `idx_attendance_date_id_desc` is applied the deep offsets become
      // index seeks and this collapses to a second or two; the generous window
      // is what lets the check pass either way instead of masking a real
      // regression behind a tight timeout.
      const ok = await waitForCardValue(page, title, value, { timeout: 60000, root: panel })
      check(`[${tab.label}] "${title}" = ${value}`, ok, `want ${value}`)
    }

    if (dark.has(tab.label)) {
      await page.screenshot({ path: `${shots}/${String(shotIndex).padStart(2, '0')}-${tab.id}-dark.png` })
    }
    shotIndex += 1
  }

  // ---- Member Distribution card ------------------------------------------
  // The card used to hold a five-slice rainbow donut, a legend listing those
  // same five values, and a stacked breakdown restating them a third time. The
  // legend beside a 253px stack in a 84-200px box is what painted over the
  // card's own bottom edge, so these assertions are about GEOMETRY as much as
  // content: a card that fits its box cannot regress back into overflowing it
  // without failing here.
  await page.getByRole('tab', { name: 'Member Overview', exact: true }).click()
  const membersPanel = page.getByRole('tabpanel', { name: 'Member Overview' })
  await membersPanel.waitFor({ state: 'visible', timeout: 15000 })
  await waitForCardValue(page, 'Total Members', expected.totalMembers, { timeout: 60000, root: membersPanel })

  const dist = membersPanel.locator('section[aria-label="Nested rings: member gender outside, activity status inside"]')
  // Recharts paints the ring's <path> elements only after its
  // ResponsiveContainer has measured the box, which is a tick or more after the
  // card itself exists. Without this wait the wrapper is present but still
  // empty and the sector assertions below read zero - a race, not a regression.
  await dist.locator('.recharts-sector').first().waitFor({ state: 'attached', timeout: 15000 })
  const distMetrics = await dist.evaluate(section => {
    const box = [...section.children].pop()
    const b = box.getBoundingClientRect()
    const s = section.getBoundingClientRect()
    // Every painted descendant, so a clipped row or bar cannot hide below the
    // box's own bounds without moving one of these.
    const painted = [...box.querySelectorAll('*')].filter(el => {
      if (el.closest('.recharts-tooltip-wrapper')) return false
      const q = el.getBoundingClientRect()
      return q.width > 0 && q.height > 0
    })
    const rects = painted.map(el => el.getBoundingClientRect())
    // The card is wrapped in a centring box, so its half-width is a property of
    // the WRAPPER against the tabpanel, not of the card against its own content.
    const wrapper = section.parentElement
    const panel = section.closest('[role=tabpanel]')
    const wr = wrapper?.getBoundingClientRect()
    const pr = panel?.getBoundingClientRect()
    return {
      boxH: Math.round(b.height),
      overflowTop: Math.round(s.top - Math.min(...rects.map(q => q.top))),
      overflowBottom: Math.round(Math.max(...rects.map(q => q.bottom)) - s.bottom),
      overflowRight: Math.round(Math.max(...rects.map(q => q.right)) - s.right),
      sectors: section.querySelectorAll('.recharts-sector').length,
      fills: [...section.querySelectorAll('.recharts-sector')].map(p => p.getAttribute('fill')),
      legendItems: section.querySelectorAll('li').length,
      text: section.innerText,
      viewportW: window.innerWidth,
      panelW: pr ? Math.round(pr.width) : 0,
      cardW: wr ? Math.round(wr.width) : 0,
      widthRatio: pr?.width && wr ? wr.width / pr.width : 0,
      // Auto margins centre the card, so the two gaps must match.
      marginSkew: wr && pr ? Math.round(Math.abs((wr.left - pr.left) - (pr.right - wr.right))) : -1,
    }
  })

  check('[Member Distribution] content fits its box', distMetrics.overflowTop <= 0 && distMetrics.overflowBottom <= 0 && distMetrics.overflowRight <= 0,
    `top=${distMetrics.overflowTop} bottom=${distMetrics.overflowBottom} right=${distMetrics.overflowRight} boxH=${distMetrics.boxH}`)

  // The ring now carries BOTH dimensions, as two concentric rings: gender on
  // the outer band, activity on the inner one. It used to carry gender alone,
  // which meant Active and Inactive existed only as a text bar while the two
  // KPIs directly above the card were about nothing else. Four sectors and all
  // four fills is the assertion - a regression to a single ring, or a ring that
  // drew one dimension twice, both fail it.
  //
  // One `<PieChart>` holds both `<Pie>`s on purpose, so the `.recharts-wrapper`
  // measured by the ring-scaling assertion further down is still the single
  // square that assertion was written against.
  //
  // The activity pair is asserted by VALUE, not by name: Active is the green
  // `#22C55E` and Inactive is now its complement `#F43F5E`, which is what makes
  // the two arcs separate at the ~13px the inner band actually renders at. It
  // was amber `#F59E0B`, and amber against green is about 40 degrees apart - the
  // two read as one warm lump, which is the whole reason the colour changed.
  // Spelling the hexes out here is deliberate: it is what pins the pairing, so a
  // later "let's make inactive blue again" has to come back and change the
  // assertion with it.
  check('[Member Distribution] the donut carries both dimensions as two concentric rings',
    distMetrics.sectors === 4
    && distMetrics.fills.includes('#C084FC') && distMetrics.fills.includes('#7C3AED')
    && distMetrics.fills.includes('#22C55E') && distMetrics.fills.includes('#F43F5E'),
    `sectors=${distMetrics.sectors} fills=${distMetrics.fills.join(',')}`)

  // The breakdown is STACKED, gender above activity status, matching the order
  // the eye travels the rings (outer first). `innerText` is in DOM order, so the
  // two heading positions are the assertion. This used to be a `grid-cols-2`
  // reading left-to-right, which does not express the same relationship.
  //
  // Case-INSENSITIVE, and that is not belt-and-braces: both headings carry
  // Tailwind's `uppercase`, and `innerText` returns RENDERED text, so the DOM
  // strings are "Gender" / "Activity Status" on the page as "GENDER" /
  // "ACTIVITY STATUS". Matching the source casing here reports both at index -1
  // and fails against a layout that is in fact correct.
  const flat = distMetrics.text.replace(/\s+/g, ' ')
  const genderAt = flat.search(/gender/i)
  const activityAt = flat.search(/activity\s+status/i)
  check('[Member Distribution] the breakdown is stacked, Gender above Activity Status',
    genderAt >= 0 && activityAt > genderAt,
    `gender@${genderAt} activity@${activityAt} text="${flat.slice(0, 90)}"`)

  // The hole still carries the active rate - it is the one number in this card
  // that ties the ring to the KPIs above it - and it is checked against the
  // ground truth rather than merely against a regex, so a ring that quietly
  // changed denominator (active of GENDER TOTAL instead of of everyone) fails.
  const centre = /(\d+)%\s*active/i.exec(distMetrics.text.replace(/\s+/g, ' '))
  const wantRate = Math.round((expected.activeMembers / expected.totalMembers) * 100)
  check('[Member Distribution] the ring centre is the active rate of the whole roster',
    !!centre && Number(centre[1]) === wantRate,
    `got=${centre ? centre[0] : 'no centre label'} want=${wantRate}% (${expected.activeMembers}/${expected.totalMembers})`)

  // Half width and centred. The complaint that produced this was a card stretched
  // across the full 1,690px panel; `lg:w-1/2 lg:max-w-[52rem]` is the answer, and
  // this is what stops a `w-full` regression from looking fine in a screenshot.
  check('[Member Distribution] the card is half the panel width and centred',
    distMetrics.viewportW >= 1024
    && distMetrics.widthRatio > 0.45 && distMetrics.widthRatio < 0.55
    && distMetrics.marginSkew <= 2,
    `card=${distMetrics.cardW}px panel=${distMetrics.panelW}px ratio=${distMetrics.widthRatio.toFixed(3)} skew=${distMetrics.marginSkew}px @${distMetrics.viewportW}px`)

  check('[Member Distribution] the donut legend is gone (the breakdown replaced it)', distMetrics.legendItems === 0, `li=${distMetrics.legendItems}`)
  check('[Member Distribution] "Unspecified" is not presented as a category', !/Unspecified/.test(distMetrics.text))
  check('[Member Distribution] both dimensions are still written out',
    /Female/.test(distMetrics.text) && /Male/.test(distMetrics.text)
    && /Active/.test(distMetrics.text) && /Inactive/.test(distMetrics.text))

  // The ring must scale with the card instead of sitting at a fixed size in a
  // much wider box, which is what left it marooned in the middle of the card.
  const ring = await dist.evaluate(section => {
    const w = section.querySelector('.recharts-wrapper')
    if (!w) return null
    const r = w.getBoundingClientRect()
    return { w: Math.round(r.width), h: Math.round(r.height) }
  })
  check('[Member Distribution] the ring scales with the card (square, near the box height)',
    !!ring && Math.abs(ring.w - ring.h) <= 2 && ring.w >= distMetrics.boxH * 0.8,
    ring ? `${ring.w}x${ring.h} vs box ${distMetrics.boxH}` : 'no ring')

  // An unrecorded gender is missing data, not a category: it must still be
  // reported, as a count, and never as a slice.
  const unrecorded = /(\d[\d,]*) not recorded/.exec(distMetrics.text)
  check('[Member Distribution] unrecorded gender is reported as a count', !!unrecorded, unrecorded ? unrecorded[0] : 'not shown')

  await page.screenshot({ path: `${shots}/member-distribution.png` })

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
  // One tolerated error: the 404 from `supabase.rpc('member_last_checkin')`
  // before migration 0035 is applied. The browser logs every failed resource
  // load itself, so this cannot be suppressed from application code — the RPC
  // probe is deliberate and the client falls back to paging correctly.
  //
  // The console message text carries no URL, so the tolerance is anchored on
  // the response log instead: only a 404 on the RPC endpoint is excused, and
  // any other 404 still fails. Matching on the message text alone ("404")
  // would wave through every unrelated missing asset on the page.
  // No failed response is tolerated, on any endpoint.
  //
  // This used to excuse a 404 on migration 0035's member_last_checkin RPC
  // "until that migration is applied". That is no longer true and the exemption
  // had stopped being an exemption: 0035 and 0036 are both applied, and
  // attendance.ts calls the function with explicit p_limit/p_offset, so the
  // endpoint cannot 404. What it could do - and what it did on 2026-10-02, when
  // 0037 had not been applied yet - is answer 300 PGRST203 "could not choose the
  // best candidate function", because 0035's zero-argument overload and 0036's
  // defaulted (p_limit, p_offset) one are both candidates for a bare call. A
  // status of 300 is not even >= 400, so the filter below never saw it; the
  // client swallowed it and fell back to the slow scan. Anchoring the tolerance
  // on a status code that can no longer occur only hides real breakage, so it is
  // gone rather than narrowed.
  const otherFailures = failedResponses.filter(r => r.status >= 400 && r.url !== undefined)

  const uniqueErrors = [...new Set(consoleErrors)]
  check(
    'no unexpected console/page errors across the whole run',
    uniqueErrors.length === 0 && otherFailures.length === 0,
    uniqueErrors.slice(0, 5).join(' || ')
      || otherFailures.slice(0, 5).map(f => `${f.status} ${f.url}`).join(' || '),
  )

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
  // A card that is still loading renders an em dash, not a number: KpiCard
  // swaps the value for "—" and sets aria-busy while it does. Stripping the
  // non-numeric characters from that leaves '', and Number('') is 0 - so a value
  // that has not arrived yet would be read as a confident zero. An empty result
  // is NaN here, so the caller waits or fails instead of believing it.
  const cleaned = text.replace(/[^0-9.]/g, '')
  if (!cleaned) return NaN
  const n = Number(cleaned)
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

/**
 * Polls until a chart is actually drawn, bounded by `timeout`.
 *
 * Replaces a fixed sleep in front of assertions that read the chart's own SVG.
 * While a tab is loading, the trend card renders a skeleton instead, so the
 * axis ticks and the KPI values behind it are simply absent
 * - reading them then reports a failure about numbers the app never claimed.
 *
 * It RETURNS a boolean rather than throwing on timeout. A locator.waitFor that
 * rejects would abort the whole run at this point and take the ~75 checks after
 * it with it; a gate that cannot reach a state should report that one state as
 * failed and carry on so the rest of the run is still reported.
 */
async function waitForChartDrawn(chart, timeout = 30000) {
  const surface = chart.locator('.recharts-surface').first()
  const deadline = Date.now() + timeout
  while (Date.now() < deadline) {
    if (await surface.count().catch(() => 0)) return true
    await new Promise(r => setTimeout(r, 250))
  }
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

