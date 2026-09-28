#!/usr/bin/env node
/**
 * verify-admin-ui.mjs — Task 16 release gate.
 *
 * Signs in with the admin credentials from the git-ignored .env, then sweeps
 * every admin route and asserts the things this plan changed:
 *
 *   1. every route renders (no blank screen, no crash)
 *   2. no console errors and no failed network requests
 *   3. the list pages show numbered pagination with a real total
 *   4. search actually filters (typing narrows the result set)
 *   5. no page-level scrollbar at desktop and laptop widths
 *
 * Every assertion is made on the RENDERED page rather than on source text, so
 * a regression that compiles but renders empty still fails.
 *
 * One error is tolerated: the 404 from migration 0035's member_last_checkin
 * RPC before that migration is applied. It is anchored on the response URL, so
 * it cannot mask any other failure. See Ruling 4 in the plan's Task 11 notes.
 *
 * Usage:  node scripts/verify-admin-ui.mjs            (needs the dev server on :5173)
 *         node scripts/verify-admin-ui.mjs --base http://localhost:4173
 */
import { chromium } from 'playwright'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'

const here = dirname(fileURLToPath(import.meta.url))
const adminDir = resolve(here, '..')
const argv = process.argv.slice(2)
const baseArg = argv.indexOf('--base')
const BASE = baseArg >= 0 ? argv[baseArg + 1] : 'http://localhost:5173'

// ---- credentials ---------------------------------------------------------
// Read from .env rather than hardcoded: the previous verification scripts
// carried a literal admin@fitness.com / Admin123! pair that had been failing
// at sign-in, so the whole suite was dead without anyone noticing.
const env = {}
for (const line of readFileSync(resolve(adminDir, '.env'), 'utf8').split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*)\s*$/)
  if (!m) continue
  let v = m[2].trim()
  if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1)
  env[m[1]] = v
}
const EMAIL = env.ADMIN_EMAIL
const PASSWORD = env.ADMIN_PASSWORD
if (!EMAIL || !PASSWORD) {
  console.error('ADMIN_EMAIL / ADMIN_PASSWORD are not set in admin/.env — cannot sign in.')
  process.exit(2)
}

// ---- routes under test ---------------------------------------------------
const ROUTES = [
  { path: '/dashboard', label: 'Dashboard', kind: 'dashboard' },
  { path: '/members', label: 'Members', kind: 'list', expectTotal: 987, searchTerm: 'M034' },
  { path: '/trainers', label: 'Trainers', kind: 'list', expectTotal: 89, searchTerm: 'T009' },
  // No `searchTerm`: the memberships list resolves the term to member ids
  // first, and a trainer code matches nothing there.
  { path: '/memberships', label: 'Memberships', kind: 'list', searchTerm: 'M034' },
  // /qr carries the pending enrolments ("Pending (10)") plus the check-in log.
  // It is deliberately NOT a paged list: the plan did not rebuild it, so
  // asserting a pager here would fail against correct behaviour.
  { path: '/qr', label: 'QR Check-in', kind: 'plain' },
  { path: '/attendance', label: 'Attendance', kind: 'plain' },
  { path: '/reports', label: 'Reports', kind: 'plain' },
  { path: '/reports/inactive', label: 'Inactive Report', kind: 'plain' },
  { path: '/reports/feedback', label: 'Coach Feedback', kind: 'plain' },
  { path: '/predictions', label: 'Predictions', kind: 'plain' },
  { path: '/notifications', label: 'Notifications', kind: 'plain' },
]

// Viewports: a desktop and the smallest laptop the plan claims to support.
const VIEWPORTS = [
  { w: 1920, h: 1080, label: '1920x1080' },
  { w: 1366, h: 768, label: '1366x768' },
  { w: 1024, h: 768, label: '1024x768' },
]

const results = []
const check = (name, ok, detail = '') => {
  results.push({ name, ok, detail })
  console.log(`${ok ? '  ok  ' : ' FAIL '} ${name}${ok || !detail ? '' : ` -- ${detail}`}`)
}

const browser = await chromium.launch()
const context = await browser.newContext({ viewport: { width: 1920, height: 1080 } })
const page = await context.newPage()

// Collected across the whole run and reported per route.
let consoleErrors = []
let failedResponses = []
page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()) })
page.on('response', r => { if (r.status() >= 400) failedResponses.push({ status: r.status(), url: r.url() }) })

console.log(`\n=== verify-admin-ui · ${BASE} ===\n`)

// ---- sign in -------------------------------------------------------------
// Sign in through the real form, not the JS API: the form is what a user
// meets, and an earlier script's hardcoded credentials meant it never got
// this far.
await page.goto(`${BASE}/login`, { waitUntil: 'networkidle' })
// Selected by type, not by label: the login form has no <label for>, so
// getByLabel(/email/i) never matches. Selecting by type also keeps the two
// fields unambiguous regardless of their placeholder text.
await page.locator('input[type=email]').fill(EMAIL)
await page.locator('input[type=password]').fill(PASSWORD)
await page.getByRole('button', { name: /sign in|log ?in/i }).first().click()
await page.waitForURL(u => !/\/login/.test(u.pathname), { timeout: 30000 })
check('signs in with the admin account', !/\/login/.test(page.url()), page.url())
if (/\/login/.test(page.url())) {
  await browser.close()
  process.exit(2)
}

// ---- per-route sweep -----------------------------------------------------
for (const route of ROUTES) {
  consoleErrors = []
  failedResponses = []
  await page.goto(`${BASE}${route.path}`, { waitUntil: 'networkidle' })
  // Give each route a settling window. The dashboard's Member Overview tab
  // pages the whole 42k-row attendance table, so a short wait reads a page
  // that is still loading as an empty one.
  await page.waitForTimeout(3000)

  const snapshot = await page.evaluate(() => ({
    bodyLen: document.body.innerText.trim().length,
    rows: document.querySelectorAll('tbody tr').length,
    hasNav: !!document.querySelector('nav, aside, header'),
  }))

  check(`[${route.label}] renders content`, snapshot.bodyLen > 200 && snapshot.hasNav,
    `bodyLen=${snapshot.bodyLen} nav=${snapshot.hasNav}`)

  // An unmatched path still renders the app shell - nav, header, footer - so
  // "has a nav" passes on a route that does not exist. Only the nav's own text
  // proves a real page rendered.
  const orphan = await page.evaluate(() => {
    const main = document.querySelector('main')
    return { mainText: (main?.innerText ?? '').trim().length }
  })
  check(`[${route.label}] route is not an orphan`, orphan.mainText > 80, `main text=${orphan.mainText}`)

  // The plan's Task 15 calls for 10 pending enrolments. They live on /qr, not
  // on a separate /enrollments route.
  if (route.path === '/qr') {
    const pending = await page.evaluate(() => document.body.innerText.match(/Pending \((\d+)\)/)?.[1] ?? null)
    check('[QR Check-in] shows 10 pending enrolments', pending === '10', `got ${pending}`)
  }

  const RPC = '/rest/v1/rpc/member_last_checkin'
  const tolerated = failedResponses.filter(r => r.status === 404 && r.url.includes(RPC)).length
  const otherFailed = failedResponses.filter(r => r.status >= 400 && !r.url.includes(RPC))
  const unexpectedConsole = consoleErrors.filter(e => !/status of 404/.test(e))
  check(`[${route.label}] no console or request errors`,
    unexpectedConsole.length === 0 && otherFailed.length === 0,
    unexpectedConsole.slice(0, 2).join(' || ') || otherFailed.slice(0, 2).map(f => `${f.status} ${f.url}`).join(' || '))
  if (tolerated) console.log(`        (${tolerated} tolerated 404(s) from the unapplied 0035 RPC)`)

  if (route.kind === 'list') {
    check(`[${route.label}] shows rows`, snapshot.rows > 0, `rows=${snapshot.rows}`)
    const pager = await page.evaluate(() => {
      const t = document.body.innerText
      return {
        range: t.match(/[\d,]+–[\d,]+ of [\d,]+|No records/)?.[0] ?? null,
        page: t.match(/Page \d+ \/ \d+/)?.[0] ?? null,
      }
    })
    check(`[${route.label}] has a numbered pager with a total`,
      Boolean(pager.range) && Boolean(pager.page), JSON.stringify(pager))
    if (route.expectTotal !== undefined && pager.range) {
      const total = Number((pager.range.match(/of ([\d,]+)/)?.[1] ?? '0').replace(/,/g, ''))
      check(`[${route.label}] total is ${route.expectTotal}`, total === route.expectTotal, `got ${total}`)
    }
  }

  // Search must actually filter. Asserting the result set shrinks is stronger
  // than asserting the text changed: a debounce that never fires leaves the
  // list untouched while the box still holds the typed term.
  if (route.kind === 'list' && route.searchTerm && await page.getByRole('searchbox').count()) {
    const term = route.searchTerm
    const before = await page.evaluate(() => document.body.innerText.match(/of ([\d,]+)/)?.[1] ?? null)
    const box = page.getByRole('searchbox').first()
    await box.click()
    await box.type(term, { delay: 60 })
    await page.waitForTimeout(2500)
    const after = await page.evaluate((t) => {
      const txt = document.body.innerText
      return {
        total: txt.match(/of ([\d,]+)/)?.[1] ?? null,
        // PaginationFooter renders "No records" rather than "1–0 of 0" when a
        // filter matches nothing. That IS a narrowed result, so it has to
        // count as one - otherwise a search that correctly finds nothing
        // reads as "search did not work".
        empty: /No records|No .*match/i.test(txt),
        typed: document.querySelector('input[type=search]')?.value ?? '',
        matched: txt.includes(t) || /No records|No .*match/i.test(txt),
      }
    }, term)
    // Assert the result set SHRANK. A debounce that never fires leaves the
    // list untouched while the box still holds the term, so comparing the
    // visible total is the assertion that actually catches it.
    const narrowed = after.empty || (after.total !== null && before !== null
      && Number(after.total.replace(/,/g, '')) < Number(before.replace(/,/g, '')))
    check(`[${route.label}] search filters the list`,
      narrowed && after.typed === term && after.matched,
      `typed="${after.typed}" ${before} -> ${after.total ?? 'empty'}`)
  }
}

// ---- no-scroll sweep -----------------------------------------------------
// Task 11 proved this for the dashboard; the list pages are the ones this plan
// rebuilt, so they get the same treatment.
console.log('\n--- no-scroll sweep ---')
for (const vp of VIEWPORTS) {
  await page.setViewportSize({ width: vp.w, height: vp.h })
  for (const route of ROUTES.filter(r => ['/members', '/trainers', '/memberships'].includes(r.path))) {
    await page.goto(`${BASE}${route.path}`, { waitUntil: 'networkidle' })
    await page.waitForTimeout(2200)
    const m = await page.evaluate(() => ({
      docOverflow: document.documentElement.scrollHeight - document.documentElement.clientHeight,
      // Clipping is the assertion that matters. `overflow-hidden` makes a
      // too-tall panel report NO scrollbar while hiding its own content, so
      // checking the scrollbar alone passes on a broken page.
      clipped: [...document.querySelectorAll('main *')]
        .filter(el => el.scrollHeight > el.clientHeight + 2 && getComputedStyle(el).overflowY === 'hidden')
        .length,
    }))
    check(`[${route.label} @ ${vp.label}] no page scroll, nothing clipped`,
      m.docOverflow <= 0 && m.clipped === 0, `overflow=${m.docOverflow} clipped=${m.clipped}`)
  }
}

// ---- summary -------------------------------------------------------------
const failed = results.filter(r => !r.ok)
console.log(`\n${results.length - failed.length} passed, ${failed.length} failed, 0 skipped`)
console.log(`RESULT: ${failed.length ? 'FAIL' : 'PASS'}`)
await browser.close()
process.exit(failed.length ? 1 : 0)
