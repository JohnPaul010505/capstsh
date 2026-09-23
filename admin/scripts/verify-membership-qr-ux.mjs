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
import { mkdirSync } from 'fs'

const base = (process.argv[2] ?? 'http://localhost:5173').replace(/\/$/, '')
const shots = 'screenshots/membership-qr-ux'
mkdirSync(shots, { recursive: true })

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

async function run() {
  const browser = await chromium.launch()
  const page = await browser.newPage({ viewport: { width: 1920, height: 1000 } })

  // ---- Sign in ---------------------------------------------------------
  await page.goto(`${base}/login`, { waitUntil: 'networkidle' })
  await page.locator('input[type=email]').fill('admin@fitness.com')
  await page.locator('input[type=password]').fill('Admin123!')
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
  await page.waitForTimeout(SETTLE_MS)
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
  await page.waitForTimeout(SETTLE_MS)
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
  await page.getByRole('button', { name: 'Renewal', exact: true }).click()
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
    await page.getByRole('button', { name: 'Daily', exact: true }).click()
    await page.waitForTimeout(600)
    renewBtn = page.getByRole('button', { name: 'Renew', exact: true }).first()
  }
  if ((await renewBtn.count()) === 0) {
    await page.getByRole('button', { name: 'Monthly', exact: true }).click()
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

  // ---- QR: pending row actions ----------------------------------------
  await page.goto(`${base}/qr`, { waitUntil: 'networkidle' })
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
    await page.screenshot({ path: `${shots}/06-qr-pending-actions.png` })
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

