/**
 * Verifies the Memberships + QR UX polish:
 *  1. New Membership drawer: the Daily/Monthly plan buttons and the 1-6
 *     duration buttons render solid #7C3AED with white text when selected.
 *  2. Monthly exposes a Custom duration; selecting it makes the End Date an
 *     editable date input and the chosen date flows into the Summary.
 *  3. The Renew action on a member row is solid purple with white text.
 *  4. The Renewal tab renders the same table chrome as Daily/Monthly,
 *     including a right-aligned "Actions" column header.
 *  5. QR Pending row actions (view / confirm / reject) read as buttons
 *     (tinted background + border) instead of faint icons.
 * Usage: node scripts/verify-membership-qr-ux.mjs [baseUrl]
 */
import { chromium } from 'playwright'
import { mkdirSync, readFileSync } from 'fs'

const base = (process.argv[2] ?? 'http://localhost:5173').replace(/\/$/, '')
const shots = 'screenshots/membership-qr-ux'
mkdirSync(shots, { recursive: true })

// Admin credentials from the git-ignored .env, not a literal pair. This script
// still carried admin@fitness.com / Admin123!, which is why it died at
// waitForURL and never reached a single assertion - the same stale-credential
// bug already fixed in verify-admin-ui.mjs and verify-dashboard-tabs.mjs.
const env = {}
for (const line of readFileSync(new URL('../.env', import.meta.url), 'utf8').split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*)\s*$/)
  if (!m) continue
  let v = m[2].trim()
  if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1)
  env[m[1]] = v
}
if (!env.ADMIN_EMAIL || !env.ADMIN_PASSWORD) {
  console.error('ADMIN_EMAIL / ADMIN_PASSWORD are not set in admin/.env - cannot sign in.')
  process.exit(2)
}

const PURPLE = 'rgb(124, 58, 237)'
const WHITE = 'rgb(255, 255, 255)'
const TRANSPARENT = 'rgba(0, 0, 0, 0)'

const results = []
const check = (name, ok, detail = '') => {
  results.push({ name, ok, detail })
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ` -- ${detail}` : ''}`)
}
const skip = (name, detail = '') => {
  results.push({ name, ok: null, detail })
  console.log(`SKIP  ${name}${detail ? ` -- ${detail}` : ''}`)
}

/** Computed background colour of the first match of a locator. */
const bgOf = locator => locator.first().evaluate(el => getComputedStyle(el).backgroundColor)
const fgOf = locator => locator.first().evaluate(el => getComputedStyle(el).color)
const borderOf = locator => locator.first().evaluate(el => getComputedStyle(el).borderTopWidth)

/** Selected-state reads must wait out `transition-all` on the plan/duration
 *  buttons: reading immediately after a click returns the pre-transition
 *  (old) colour and reports a false failure. */
const SETTLE_MS = 300

/**
 * Wait until an element's computed background is the expected colour.
 *
 * A fixed `waitForTimeout(300)` after a click is a race between three things -
 * the click, React's commit, and the CSS transition - and under load (a Vite dev
 * server, a Playwright session, the dashboard's own polling) the transition is
 * still running at 300ms, so the assertion reads a colour from the middle of the
 * animation: `rgba(124, 58, 237, 0.973)` where the settled value is
 * `rgb(124, 58, 237)`.
 *
 * "Wait until the colour stops changing" is NOT the fix, and this file proved it:
 * that variant can stabilise on the value from BEFORE the click, because React
 * has not committed the state change yet and the first two polls both see the
 * old colour. The trace it printed was
 * `["rgba(255,255,255,0.08)", "rgb(124,58,237)", "rgb(124,58,237)", ...]` - it
 * returned during the gap.
 *
 * These assertions are about a specific colour, so the wait is for that colour.
 * `not: true` waits for it to become anything else, which is how a deselected
 * button is confirmed rather than assumed.
 */
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms))

async function waitForColour(locator, expected, { not = false, timeout = 5000 } = {}) {
  const deadline = Date.now() + timeout
  for (;;) {
    const seen = await bgOf(locator)
    if (not ? seen !== expected : seen === expected) return seen
    if (Date.now() > deadline) return seen
    await sleep(60)
  }
}

async function run() {
  const browser = await chromium.launch()
  const page = await browser.newPage({ viewport: { width: 1920, height: 1000 } })

  // ---- Sign in ---------------------------------------------------------
  await page.goto(`${base}/login`, { waitUntil: 'networkidle' })
  await page.locator('input[type=email]').fill(env.ADMIN_EMAIL)
  await page.locator('input[type=password]').fill(env.ADMIN_PASSWORD)
  await page.locator('button[type=submit]').click()
  await page.waitForURL(u => !u.pathname.includes('/login'), { timeout: 25000 })
  console.log(`signed in -> ${page.url()}`)

  // ---- Memberships: New Membership drawer ------------------------------
  await page.goto(`${base}/memberships`, { waitUntil: 'networkidle' })
  await page.getByRole('button', { name: 'Add Membership' }).click()
  const drawer = page.locator('div.slide-in-right')
  await drawer.waitFor({ state: 'visible' })

  const dailyBtn = drawer.getByRole('button', { name: 'Daily', exact: true })
  const monthlyBtn = drawer.getByRole('button', { name: 'Monthly', exact: true })

  // Daily is the default selection.
  check('plan button (Daily) selected = solid purple', (await bgOf(dailyBtn)) === PURPLE, await bgOf(dailyBtn))
  check('plan button (Daily) selected = white text', (await fgOf(dailyBtn)) === WHITE, await fgOf(dailyBtn))

  await monthlyBtn.click()
  await waitForColour(monthlyBtn, PURPLE)
  check('plan button (Monthly) selected = solid purple', (await bgOf(monthlyBtn)) === PURPLE, await bgOf(monthlyBtn))
  check('plan button (Monthly) selected = white text', (await fgOf(monthlyBtn)) === WHITE, await fgOf(monthlyBtn))

  // Duration 1-6 + Custom.
  const oneBtn = drawer.getByRole('button', { name: '1', exact: true })
  const customBtn = drawer.getByRole('button', { name: 'Custom', exact: true })
  check('duration 1 selected = solid purple', (await bgOf(oneBtn)) === PURPLE, await bgOf(oneBtn))
  check('duration 1 selected = white text', (await fgOf(oneBtn)) === WHITE, await fgOf(oneBtn))
  check('Custom duration button exists', (await customBtn.count()) === 1)
  await page.screenshot({ path: `${shots}/01-drawer-monthly-1month.png` })

  // Custom -> editable end date.
  await customBtn.click()
  // Two waits, not one: Custom being selected and duration 1 being released are
  // two separate renders, and reading `oneAfter` between them catches the frame
  // where Custom is purple and 1 has not been cleared yet.
  await waitForColour(customBtn, PURPLE)
  await waitForColour(oneBtn, PURPLE, { not: true })
  check('Custom selected = solid purple', (await bgOf(customBtn)) === PURPLE, await bgOf(customBtn))
  check('Custom selected = white text', (await fgOf(customBtn)) === WHITE, await fgOf(customBtn))
  const oneAfter = await bgOf(oneBtn)
  check('duration 1 deselected when Custom is on', oneAfter !== PURPLE, oneAfter)

  const endInput = drawer.locator('input[type=date]').last()
  check('end date becomes an editable date input', (await endInput.count()) > 0 && (await endInput.isEditable()))
  const customEnd = '2026-12-31'
  await endInput.fill(customEnd)
  const summaryShowsCustom = (await drawer.getByText(customEnd, { exact: false }).count()) > 0
  check('custom end date reaches the Summary', summaryShowsCustom, customEnd)

  // Invalid custom range must block Create.
  await endInput.fill('2026-01-01')
  const invalidMsg = await drawer.getByText('Custom end date must be after the start date.').count()
  const createDisabled = await drawer.getByRole('button', { name: 'Create', exact: true }).isDisabled()
  check('end date before start date shows the error', invalidMsg > 0)
  check('end date before start date disables Create', createDisabled)
  await page.screenshot({ path: `${shots}/02-drawer-custom-invalid.png` })

  // Restore a valid custom range for the reference screenshot.
  await endInput.fill(customEnd)
  await page.screenshot({ path: `${shots}/03-drawer-custom-valid.png` })
  await drawer.getByRole('button', { name: 'Cancel', exact: true }).click()

  // ---- Memberships: table tabs ----------------------------------------
  // These are ARIA tabs, not buttons. They were plain buttons when this script
  // was written, and the list-page rebuild made them role="tab" - so
  // getByRole('button') silently matched nothing and the run died on a 30s
  // wait instead of failing on an assertion.
  await page.getByRole('tab', { name: 'Renewal', exact: true }).click()
  await page.waitForTimeout(600)
  const renewalHeaders = await page.locator('th').allInnerTexts()
  check('renewal table has an Actions column header', renewalHeaders.includes('Actions'), renewalHeaders.join(' | '))
  check(
    'renewal table headers match the Daily/Monthly set',
    ['Member', 'Plan', 'Requested', 'Actions'].every(h => renewalHeaders.includes(h)),
    renewalHeaders.join(' | '),
  )
  const renewalRows = page.locator('tbody tr')
  const rowDivider = (await renewalRows.count()) > 0
    ? await renewalRows.first().evaluate(el => getComputedStyle(el).borderBottomWidth)
    : '0px'
  check('renewal rows are separated by a divider line', rowDivider !== '0px', rowDivider)
  await page.screenshot({ path: `${shots}/04-renewal-table.png` })

  // Renew button style (rows carry it on the member's plan tab).
  let renewBtn = page.getByRole('button', { name: 'Renew', exact: true }).first()
  if ((await renewBtn.count()) === 0) {
    await page.getByRole('tab', { name: 'Daily', exact: true }).click()
    await page.waitForTimeout(600)
    renewBtn = page.getByRole('button', { name: 'Renew', exact: true }).first()
  }
  if ((await renewBtn.count()) === 0) {
    await page.getByRole('tab', { name: 'Monthly', exact: true }).click()
    await page.waitForTimeout(600)
    renewBtn = page.getByRole('button', { name: 'Renew', exact: true }).first()
  }
  if ((await renewBtn.count()) === 0) {
    skip('Renew button is solid purple with white text', 'no RENEWAL REQUESTED row in this dataset')
  } else {
    check('Renew button is solid purple', (await bgOf(renewBtn)) === PURPLE, await bgOf(renewBtn))
    check('Renew button has white text', (await fgOf(renewBtn)) === WHITE, await fgOf(renewBtn))
    await page.screenshot({ path: `${shots}/05-renew-button.png` })
  }

  // ---- QR: the codes view, then the pending row actions ----------------
  // The pending list is no longer on the landing view - /qr opens on the two QR
  // codes and Pending is one click away - so this pass has to open the tab
  // before the row actions exist in the DOM. Asserting the landing view first
  // is also the regression guard for that split: codes and a table on one
  // screen is exactly what the page used to do badly.
  await page.goto(`${base}/qr`, { waitUntil: 'networkidle' })
  await page.waitForTimeout(800)
  const landing = await page.evaluate(() => ({
    // `[data-qr]` is the card, not the <svg>: the codes are now measured to fill
    // their card, so the old `svg[height="160"]` probe would match nothing the
    // moment the size moved off 160.
    codes: document.querySelectorAll('main [data-qr]').length,
    rows: document.querySelectorAll('main tbody tr').length,
  }))
  check('QR landing view shows both codes and no table', landing.codes === 2 && landing.rows === 0,
    `codes=${landing.codes} rows=${landing.rows}`)

  // The codes are measured to fill their card (`useFitSquare`), which sets a
  // side length from the card's own box and then clamps it. That clamp is the
  // guard that stops a code on a 1080p monitor from growing to the full width
  // of its card and reading as a mistake rather than a poster, so it is worth
  // asserting: a ceiling that silently stopped applying would let the QR run
  // away with the layout, and one that was set too low would shrink a code
  // meant to be scanned off a gym wall.
  //
  // 500 is the measured ceiling. The un-capped fit is 342px at 1024x768, 513px
  // at 1366x768 and 892px at 1920x1080, so the cap decides the two larger
  // viewports and 1024 is free to fill its card.
  const QR_CEILING = 500
  for (const [w, h] of [[1920, 1080], [1366, 768], [1024, 768]]) {
    await page.setViewportSize({ width: w, height: h })
    await page.waitForTimeout(500)
    const codes = await page.evaluate(() => [...document.querySelectorAll('main [data-qr] svg[viewBox]')].map(svg => {
      const r = svg.getBoundingClientRect()
      const card = svg.closest('[data-qr]').getBoundingClientRect()
      return { side: Math.round(r.width), square: Math.abs(r.width - r.height) <= 1, cardW: Math.round(card.width) }
    }))
    check(`[QR @ ${w}x${h}] both codes are square and within the ${QR_CEILING}px ceiling`,
      codes.length === 2 && codes.every(c => c.square && c.side <= QR_CEILING),
      codes.map(c => `${c.side}px/${c.cardW}px`).join(' '))
  }
  await page.setViewportSize({ width: 1920, height: 1000 })
  await page.waitForTimeout(400)
  await page.screenshot({ path: `${shots}/06-qr-codes.png` })

  await page.getByRole('tab', { name: /Pending/ }).click()
  await page.waitForTimeout(800)
  const viewBtn = page.locator('button[title="View"]').first()
  const confirmBtn = page.locator('button[title="Confirm"]').first()
  const rejectBtn = page.locator('button[title="Reject"]').first()
  if ((await viewBtn.count()) === 0) {
    skip('QR pending action buttons are visible', 'no pending enrollments in this dataset')
  } else {
    for (const [label, loc] of [['view', viewBtn], ['confirm', confirmBtn], ['reject', rejectBtn]]) {
      const colour = await bgOf(loc)
      const border = await borderOf(loc)
      check(`QR ${label} action has a tinted background`, colour !== TRANSPARENT, colour)
      check(`QR ${label} action has a border`, border !== '0px', border)
    }
    await page.screenshot({ path: `${shots}/07-qr-pending-actions.png` })
  }

  await browser.close()

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

