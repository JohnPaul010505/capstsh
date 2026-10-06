#!/usr/bin/env node
/**
 * verify-admin-ui.mjs — Task 16 release gate.
 *
 * Signs in with the admin credentials from the git-ignored .env, then sweeps
 * every admin route and asserts the things this plan changed:
 *
 *   1. every route renders (no blank screen, no crash)
 *   2. no console errors and no failed network requests
 *   3. the list pages end on the same compact records footer as every other
 *      list in the app, with a real total
 *   4. search actually filters (typing narrows the result set)
 *   5. no page-level scrollbar at desktop and laptop widths
 *   6. the list pages show exactly 15 rows with a table body that does not
 *      scroll, and the memberships tabs behave (own Code column, working search
 *      on the Renewal tab)
 *
 * Every assertion is made on the RENDERED page rather than on source text, so
 * a regression that compiles but renders empty still fails.
 *
 * No failed response is tolerated. This sweep used to wave through a 404 on
 * migration 0035's member_last_checkin RPC "until that migration is applied",
 * but 0035 IS applied (its RPC answers) and 0036 has since added the paging
 * parameters, so the exemption now only hides real breakage.
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
  // /qr is a paged list page, but in VIEWS: it opens on the two QR codes with
  // Pending and Confirmed a click away, so the generic list sweep (which wants
  // the records pager on the landing render) cannot describe it. It gets its own
  // sweep further down, plus a cell in the no-scroll table below.
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

// This sweep walks 12 heavy routes in ONE page, so by the later routes the app
// has already pulled the full dataset several times over and the accumulated
// PostgREST requests push the next navigation past Playwright's 30 s default.
// That is a budget problem, not a page problem: /notifications reaches
// networkidle in ~1.3 s when loaded on its own. Crashing the whole run at the
// route that happened to tip over reported NOTHING about the routes after it,
// so the budget is raised rather than the assertions touched.
page.setDefaultNavigationTimeout(60000)

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

  // Strict: a 404 on the last-checkin RPC is a real failure now, not a
  // pre-migration state.
  const otherFailed = failedResponses.filter(r => r.status >= 400)
  const unexpectedConsole = consoleErrors.filter(e => !/status of 404/.test(e))
  check(`[${route.label}] no console or request errors`,
    unexpectedConsole.length === 0 && otherFailed.length === 0,
    unexpectedConsole.slice(0, 2).join(' || ') || otherFailed.slice(0, 2).map(f => `${f.status} ${f.url}`).join(' || '))


  if (route.kind === 'list') {
    check(`[${route.label}] shows rows`, snapshot.rows > 0, `rows=${snapshot.rows}`)
    // The footer these three pages end on used to be a numbered pager plus a
    // "Page 1 / 66" label. It is now the compact row the QR queue and every
    // dashboard tab already used, so the assertions are written against THAT
    // wording. Worth being explicit about, because the old range regex was
    // unanchored: it matched the tail of "Showing 1-15 of 987 records" as well
    // as "1-15 of 987", so it would have gone on passing through this change and
    // proved nothing about whether the pager had actually moved.
    const pager = await page.evaluate(() => {
      const t = document.body.innerText
      return {
        range: t.match(/Showing [\d,]+–[\d,]+ of [\d,]+ records|No records/)?.[0] ?? null,
        page: t.match(/(?:^|\s)(\d+ \/ \d+)(?:\s|$)/)?.[0]?.trim() ?? null,
      }
    })
    check(`[${route.label}] has the records pager with a total`,
      Boolean(pager.range) && Boolean(pager.page), JSON.stringify(pager))
    if (route.expectTotal !== undefined && pager.range) {
      const total = Number((pager.range.match(/of ([\d,]+)/)?.[1] ?? '0').replace(/,/g, ''))
      check(`[${route.label}] total is ${route.expectTotal}`, total === route.expectTotal, `got ${total}`)
    }

    // The page size is PINNED at 15 (LIST_PAGE_SIZE) and the row height is
    // measured to fit. Both halves matter: a 25-row page inside a body that fits
    // 14 is what produced the scrollbar, and a "measured" page size made the
    // count drift with the window. Asserting the count alone would pass on a
    // page that still scrolls, so the overflow is asserted too.
    const fit = await page.evaluate(() => {
      const table = document.querySelector('main table')
      const scroller = table?.closest('.overflow-auto')
      return {
        rows: document.querySelectorAll('main tbody tr').length,
        // 2px of slack for sub-pixel rounding on the sticky header.
        overflow: scroller ? scroller.scrollHeight - scroller.clientHeight : -1,
        rowHeight: Math.round(document.querySelector('main tbody tr')?.getBoundingClientRect().height ?? 0),
      }
    })
    check(`[${route.label}] shows exactly 15 rows on page 1`, fit.rows === 15,
      `rows=${fit.rows} rowHeight=${fit.rowHeight}px`)
    check(`[${route.label}] table body does not scroll`, fit.overflow <= 2,
      `overflow=${fit.overflow}px rows=${fit.rows} rowHeight=${fit.rowHeight}px`)

    // The `#` column and the pager sitting inside the card are the two things
    // that make these pages read as the same component as the QR queue. They
    // are cheap to assert and they are what a second, older kind of list looks
    // like when it creeps back in.
    const chrome = await page.evaluate(() => {
      const table = document.querySelector('main table')
      const card = table?.closest('section')
      return {
        firstHead: table?.querySelector('thead th')?.textContent?.trim() ?? null,
        pagerInCard: /of [\d,]+ records|No records/.test(card?.textContent ?? ''),
        index: Array.from(table?.querySelectorAll('tbody tr td:first-child') ?? [])
          .slice(0, 3).map(td => td.textContent?.trim()),
      }
    })
    check(`[${route.label}] leads the table with a # index column`,
      chrome.firstHead === '#', JSON.stringify(chrome))
    check(`[${route.label}] keeps the pager inside the table card`,
      chrome.pagerInCard, JSON.stringify(chrome))
    check(`[${route.label}] numbers rows through the whole result set`,
      chrome.index.join(',') === '1,2,3', JSON.stringify(chrome.index))
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

// ---- memberships specifics ---------------------------------------------
// The generic sweep can only ever look at the FIRST tab, so the two things
// that live on the other tabs need their own pass: the Renewal tab used to
// render no search box at all, and the member's code used to be printed inside
// the name cell on every tab.
console.log('\n--- memberships tab sweep ---')
await page.goto(`${BASE}/memberships`, { waitUntil: 'networkidle' })
await page.waitForTimeout(2000)

const memberCols = await page.evaluate(() => {
  const heads = [...document.querySelectorAll('main thead th')].map(th => th.innerText.trim())
  const cells = [...document.querySelectorAll('main tbody tr:first-child td')].map(td => td.innerText.trim())
  return { heads, cells }
})
const codeIndex = memberCols.heads.indexOf('Code')
check('[Memberships] has a Code column of its own', codeIndex > 0, JSON.stringify(memberCols.heads))
check('[Memberships] the code is not printed beside the name',
  !/\b[MT]\d{3}\b/.test(memberCols.cells[0] ?? '') && /^[MT]\d{3}$/.test(memberCols.cells[codeIndex] ?? ''),
  `member="${memberCols.cells[0]}" code="${memberCols.cells[codeIndex]}"`)

await page.getByRole('tab', { name: 'Renewal' }).click()
await page.waitForTimeout(2000)

const renewBefore = await page.evaluate(() => document.querySelectorAll('main tbody tr').length)
check('[Memberships] Renewal tab renders its queue', renewBefore > 0, `rows=${renewBefore}`)

const renewCode = await page.evaluate(() => {
  const heads = [...document.querySelectorAll('main thead th')].map(th => th.innerText.trim())
  const i = heads.indexOf('Code')
  const cell = document.querySelector(`main tbody tr:first-child td:nth-child(${i + 1})`)
  return cell?.innerText.trim() ?? ''
})
// The same search box, now on top of the Renewal tab. Searching by a member
// code from the queue is the strongest form of the assertion: the term has to
// reach rows the Daily/Monthly query path cannot even see.
const renewBox = page.getByRole('searchbox').first()
await renewBox.click()
await renewBox.type(renewCode, { delay: 60 })
await page.waitForTimeout(2000)
const renewAfter = await page.evaluate(() => document.querySelectorAll('main tbody tr').length)
check('[Memberships] Renewal search narrows the queue',
  renewAfter > 0 && renewAfter < renewBefore, `typed="${renewCode}" ${renewBefore} -> ${renewAfter} rows`)

// A term that matches nothing must read as an empty queue, not as a queue that
// ignored the search.
await renewBox.fill('')
await renewBox.type('zzzznotamember', { delay: 40 })
await page.waitForTimeout(2000)
const renewEmpty = await page.evaluate(() => ({
  rows: document.querySelectorAll('main tbody tr').length,
  text: document.body.innerText,
}))
check('[Memberships] Renewal search can empty the queue',
  renewEmpty.rows === 1 && /No renewal requests match/i.test(renewEmpty.text),
  `rows=${renewEmpty.rows}`)

// Clear the search and click a queue row. The full request panel is where the
// member's note and email live now that the row itself is one line, so if the
// row stopped being clickable that information would be unreachable.
await renewBox.fill('')
await page.waitForTimeout(1500)
await page.locator('main tbody tr').first().click()
await page.waitForTimeout(800)
const panelOpened = await page.evaluate(() =>
  /Note from Member|Requested On|Approve Renewal/.test(document.body.innerText))
check('[Memberships] clicking a queue row opens the request panel', panelOpened)

// ---- QR views --------------------------------------------------------------
// /qr is a paged list page now, but it is NOT one of the generic `kind: 'list'`
// routes: that sweep asserts the records pager ("Showing 1-15 of 45 records",
// "1 / 3") and
// exactly 15 rows on the landing render, and /qr opens on the QR codes with
// Pending and Confirmed one click away. So the three views are swept here
// instead, with the same three questions asked of each: is the right content on
// screen, does the pager describe it honestly, and does the body scroll.
console.log('\n--- qr views sweep ---')
await page.goto(`${BASE}/qr`, { waitUntil: 'networkidle' })
await page.waitForTimeout(1800)

const codes = await page.evaluate(() => ({
  // `[data-qr]` is the card, not the <svg>: the codes are measured to fill their
  // card, so the old `svg[height="160"]` probe matches nothing once the size
  // moves off 160.
  codes: document.querySelectorAll('main [data-qr]').length,
  rows: document.querySelectorAll('main tbody tr').length,
}))
check('[QR] landing view is the two codes, with no list', codes.codes === 2 && codes.rows === 0,
  `codes=${codes.codes} rows=${codes.rows}`)

// The pair SPANS the content width: the left card is hard against the left edge
// of `main` and the right card against the right edge, with a real gap between
// them and the same width each.
//
// This used to assert the opposite - that the pair was CENTRED with equal
// margins - which was the correct contract for the old fixed 160px cards in a
// `place-items-center` wrapper. The codes are now sized to their card, so a
// centred island would leave the measured square smaller than the space it has.
// Centredness is a relationship between the two cards; spanning is a
// relationship between the cards and the page, so that is what is measured.
const spanned = await page.evaluate(() => {
  const cards = [...document.querySelectorAll('main [data-qr]')]
  if (cards.length !== 2) return { ok: false, count: cards.length }
  const [a, b] = cards.map(c => c.getBoundingClientRect())
  const mainEl = document.querySelector('main')
  const main = mainEl.getBoundingClientRect()
  const gap = Math.abs(b.left - a.right)
  const leftSlack = a.left - main.left
  const rightSlack = main.right - b.right
  // `main` is `px-1`, so its BORDER box is 4px wider than the content the page
  // actually fills. "Flush" therefore means flush with the content box, and the
  // slack has to be compared against that padding - the first version of this
  // check compared against the border box and failed on a perfect layout.
  const cs = getComputedStyle(mainEl)
  const padL = parseFloat(cs.paddingLeft)
  const padR = parseFloat(cs.paddingRight)
  return {
    ok: true,
    // Each card hugs its own content edge, clears the other by a visible gap,
    // and the two are the same width.
    spans: Math.abs(leftSlack - padL) <= 2 && Math.abs(rightSlack - padR) <= 2,
    evenWidth: Math.abs(a.width - b.width) <= 2,
    gap,
    leftSlack: Math.round(leftSlack),
    rightSlack: Math.round(rightSlack),
    padL,
    padR,
    widthA: Math.round(a.width),
    widthB: Math.round(b.width),
  }
})
check('[QR] the two codes span the full content width', spanned.ok && spanned.spans && spanned.evenWidth && spanned.gap > 8,
  JSON.stringify(spanned))

const readTable = () => page.evaluate(() => {
  const table = document.querySelector('main table')
  const scroller = table?.closest('.overflow-auto')
  const text = document.body.innerText
  return {
    rows: document.querySelectorAll('main tbody tr').length,
    overflow: scroller ? scroller.scrollHeight - scroller.clientHeight : -1,
    range: text.match(/Showing ([\d,]+)–([\d,]+) of ([\d,]+) records/)?.[0] ?? null,
    page: text.match(/\b(\d+ \/ \d+)\b/)?.[1] ?? null,
    // The first email, used below to prove the in-card search really filters.
    firstEmail: document.querySelector('main tbody tr td:nth-child(3)')?.innerText?.trim() ?? null,
  }
})

await page.getByRole('tab', { name: /Pending/ }).click()
await page.waitForTimeout(900)
const pendingTable = await readTable()
check('[QR] Pending view pages its rows', pendingTable.rows === 10 && pendingTable.range === 'Showing 1–10 of 10 records',
  `rows=${pendingTable.rows} range=${pendingTable.range}`)
check('[QR] Pending body does not scroll', pendingTable.overflow <= 2, `overflow=${pendingTable.overflow}px`)
check('[QR] Pending row actions survived the move into a table',
  (await page.locator('button[title="View"]').count()) > 0
  && (await page.locator('button[title="Confirm"]').count()) > 0
  && (await page.locator('button[title="Reject"]').count()) > 0)

if (pendingTable.firstEmail) {
  const box = page.getByRole('searchbox').first()
  await box.click()
  await box.fill(pendingTable.firstEmail)
  await page.waitForTimeout(700)
  const narrowed = await readTable()
  check('[QR] Pending search narrows the queue',
    narrowed.rows === 1 && narrowed.range === 'Showing 1–1 of 1 records',
    `typed="${pendingTable.firstEmail}" range=${narrowed.range}`)
  await box.fill('')
  await page.waitForTimeout(500)
}

// The page size is measured from the space the table has, so it is not a fixed
// number here: what has to hold is that the page is FULL (a page that is not
// full means the measurement is lying), that the footer agrees with the rows on
// screen, and that the body never scrolls.
await page.getByRole('tab', { name: /Confirmed/ }).click()
await page.waitForTimeout(1200)
const confirmed1 = await readTable()
const pageSize1 = confirmed1.rows
const pages1 = Math.ceil(45 / pageSize1)
check('[QR] Confirmed view fills its page', pageSize1 > 1 && pageSize1 < 45,
  `rows=${pageSize1} of 45`)
check('[QR] Confirmed footer agrees with the rows on screen',
  confirmed1.range === `Showing 1–${pageSize1} of 45 records`, `range=${confirmed1.range}`)
check('[QR] Confirmed pager counts the pages', confirmed1.page === `1 / ${pages1}`,
  `page=${confirmed1.page} want=1 / ${pages1}`)
check('[QR] Confirmed body does not scroll', confirmed1.overflow <= 2, `overflow=${confirmed1.overflow}px`)

await page.getByRole('button', { name: 'Next page' }).click()
await page.waitForTimeout(700)
const confirmed2 = await readTable()
const from2 = pageSize1 + 1
const to2 = Math.min(45, pageSize1 * 2)
check('[QR] Confirmed next page advances the window',
  confirmed2.rows === pageSize1
  && confirmed2.range === `Showing ${from2}–${to2} of 45 records`
  && confirmed2.page === `2 / ${pages1}`,
  `rows=${confirmed2.rows} range=${confirmed2.range} page=${confirmed2.page}`)

await page.getByRole('tab', { name: 'QR Codes' }).click()
await page.waitForTimeout(700)
const backToCodes = await page.evaluate(() => document.querySelectorAll('main tbody tr').length)
check('[QR] returning to the codes view leaves the table behind', backToCodes === 0, `rows=${backToCodes}`)

// ---- reports lists: inactive members/trainers + recent feedback ---------
// Both pages now render through the same RecordsTable the QR Pending queue uses,
// so both are asked the same three questions the QR views get: is the list paged,
// does the pager describe what is on screen honestly, and does the body scroll.
// Before this they were two hand-rolled tables inside `max-h-[420px]` scrollers
// with no pager, no `#` column and no search - and because a page that clips its
// own content reports no scrollbar at all, nothing caught the rows that were
// simply unreachable.
console.log('\n--- reports lists sweep ---')

const readRecords = () => page.evaluate(() => {
  const table = document.querySelector('main table')
  const scroller = table?.closest('.overflow-auto')
  const text = document.body.innerText
  return {
    rows: document.querySelectorAll('main tbody tr').length,
    overflow: scroller ? scroller.scrollHeight - scroller.clientHeight : -1,
    // Carried in the detail of every overflow check: `useFitRows` budgets 44px a
    // row and 40px of header, so a body that overflows is a row or a header that
    // is TALLER than the budget, and the two numbers are the only way to tell
    // which. The first run of this sweep reported a bare "overflow=15px".
    clientH: scroller ? scroller.clientHeight : -1,
    scrollH: scroller ? scroller.scrollHeight : -1,
    rowHeight: Math.round(document.querySelector('main tbody tr')?.getBoundingClientRect().height ?? 0),
    range: text.match(/Showing ([\d,]+)–([\d,]+) of ([\d,]+) records/)?.[0] ?? null,
    page: text.match(/\b(\d+ \/ \d+)\b/)?.[1] ?? null,
    heads: [...document.querySelectorAll('main thead th')].map(th => th.innerText.trim()),
    // Column 2 is the name (column 1 is the `#` index).
    firstName: document.querySelector('main tbody tr td:nth-child(2)')?.innerText?.trim() ?? null,
  }
})

// ---- inactive report ------------------------------------------------------
await page.goto(`${BASE}/reports/inactive`, { waitUntil: 'networkidle' })
// Both sub-tab queries now run on mount so the labels can carry counts, so the
// wait only has to cover the second of the two.
await page.waitForTimeout(3000)

const inactive = await readRecords()
check('[Inactive Report] the members list is paged',
  inactive.rows > 1
  && /^Showing 1–\d+ of [\d,]+ records$/.test(inactive.range ?? '')
  && /^\d+ \/ \d+$/.test(inactive.page ?? ''),
  `rows=${inactive.rows} range=${inactive.range} page=${inactive.page}`)
check('[Inactive Report] the table body does not scroll', inactive.overflow <= 2, `overflow=${inactive.overflow}px`)
// The code used to sit in a second line inside the name cell. RecordsTable
// measures rows at one 44px line, so it had to become a column of its own - and
// an assertion is what keeps it from being folded back in.
check('[Inactive Report] the row index and the member ID are columns of their own',
  inactive.heads[0] === '#' && inactive.heads.some(h => /Member ID/i.test(h)),
  JSON.stringify(inactive.heads))
const notifyCount = await page.getByRole('button', { name: /^Notify$/ }).count()
check('[Inactive Report] every row still carries its Notify action',
  (await page.locator('main tbody button').count()) === inactive.rows && notifyCount > 0,
  `rows=${inactive.rows} notify=${notifyCount}`)
if (inactive.firstName) {
  const box = page.getByRole('searchbox').first()
  await box.click()
  await box.fill(inactive.firstName)
  await page.waitForTimeout(700)
  const narrowed = await readRecords()
  check('[Inactive Report] search narrows the list',
    narrowed.rows === 1 && narrowed.range === 'Showing 1–1 of 1 records',
    `typed="${inactive.firstName}" range=${narrowed.range}`)
  await box.fill('')
  await page.waitForTimeout(500)
}

// The trainers view is a different query with a different threshold, so it gets
// its own read - and it is allowed to legitimately be EMPTY, which is why the
// assertion branches on the count the tab label is showing.
const trainersTab = page.getByRole('tab', { name: /Inactive Trainers/ })
const trainerCount = Number(/\((\d+)\)/.exec(await trainersTab.innerText())?.[1] ?? '0')
await trainersTab.click()
await page.waitForTimeout(1200)
const trainers = await readRecords()
const trainersOk = trainerCount === 0
  ? /No inactive trainers/.test(await page.locator('main').innerText())
  : trainers.rows > 0
    && trainers.heads.includes('Trainer')
    && /^Showing 1–\d+ of [\d,]+ records$/.test(trainers.range ?? '')
check('[Inactive Report] the trainers tab is its own paged list',
  trainersOk, `count=${trainerCount} rows=${trainers.rows} range=${trainers.range} heads=${JSON.stringify(trainers.heads)}`)

// ---- coach feedback -------------------------------------------------------
await page.goto(`${BASE}/reports/feedback`, { waitUntil: 'networkidle' })
await page.waitForTimeout(2500)

const feedback = await readRecords()
check('[Coach Feedback] recent feedback is paged',
  feedback.rows > 1 && /^Showing 1–\d+ of 50 records$/.test(feedback.range ?? ''),
  `rows=${feedback.rows} range=${feedback.range} page=${feedback.page}`)
check('[Coach Feedback] the table body does not scroll', feedback.overflow <= 2,
  `overflow=${feedback.overflow}px clientH=${feedback.clientH} scrollH=${feedback.scrollH} rows=${feedback.rows} rowHeight=${feedback.rowHeight}px`)

// The average rating is a KPI card again (icon tile, title, value, sub) at half
// the panel and centred. Measured against `main` rather than eyeballed from a
// screenshot, because "half width" and "centred" are two different claims.
const rating = await page.evaluate(() => {
  const main = document.querySelector('main')
  const mr = main.getBoundingClientRect()
  const card = [...main.querySelectorAll('.glass-card')]
    .find(c => /Average Member Rating/.test(c.innerText))
  if (!card) return null
  const r = card.getBoundingClientRect()
  // The date filter, and whether it shares the card's ROW. The card used to be
  // centred on a row of its own with the picker stranded on the row below it,
  // which is exactly what made it read as floating; the fix was to put the two
  // on ONE line, so "shares a row" is the claim worth asserting and "centred"
  // is now the claim that would be WRONG.
  const picker = [...main.querySelectorAll('button[aria-haspopup="dialog"]')]
    .find(b => /Date range/i.test(b.getAttribute('aria-label') ?? ''))
  const pr = picker?.getBoundingClientRect()
  return {
    text: card.innerText.replace(/\s+/g, ' ').trim(),
    cardW: Math.round(r.width),
    panelW: Math.round(mr.width),
    leftGap: Math.round(r.left - mr.left),
    rightGap: Math.round(mr.right - r.right),
    pickerFound: !!picker,
    // Vertical overlap rather than a top-edge comparison: the two sit on one
    // line without sharing a top, and a few px of padding should not decide it.
    sameRow: !!pr && r.top < pr.bottom && pr.top < r.bottom,
    // `KpiCard` renders the star row as a single role="img" with an aria-label.
    starRows: card.querySelectorAll('[role=img]').length,
  }
})
check('[Coach Feedback] the rating card is half-width, left-anchored, and shares a line with the date filter',
  !!rating && rating.cardW <= 852 && rating.cardW > 380
  // Left-anchored, not centred: a centred card has equal gaps, so demanding a
  // materially smaller left gap is what distinguishes the two.
  && rating.leftGap + 20 < rating.rightGap
  && rating.pickerFound && rating.sameRow
  && /\d\.\d/.test(rating.text) && rating.starRows === 1,
  JSON.stringify(rating))

const feedbackNote = await page.evaluate(() =>
  document.querySelector('main tbody tr td:nth-child(4)')?.innerText?.trim() ?? null)
const feedbackBefore = await readRecords()

if (feedbackNote) {
  const box = page.getByRole('searchbox').first()
  await box.click()
  // The row truncates at 22rem, so the note on screen is a prefix of the full
  // text. Search runs against the full value, so a prefix matches every row
  // that opens with it - and the notes come from a small pool, so that is
  // several rows rather than one. Demanding a unique prefix was testing the
  // seed's vocabulary, not the search box; what must hold is that every row
  // that came back contains the typed text, which is what proves search reads
  // the note column and not the truncated cell.
  const term = feedbackNote.slice(0, 24)

  await box.fill(term)
  await page.waitForTimeout(700)
  const narrowed = await readRecords()
  // Every row that came back must really contain the typed text. That is a
  // stronger claim than "exactly one row", not a weaker one: it holds however
  // many rows share the prefix, and it is what actually pins the search to the
  // note column instead of the truncated cell.
  const matchedNotes = await page.evaluate(() =>
    [...document.querySelectorAll('main tbody tr')]
      .map(tr => tr.querySelector('td:nth-child(4)')?.innerText?.trim() ?? ''))
  const allMatched = matchedNotes.length > 0
    && matchedNotes.every(n => n.toLowerCase().includes(term.toLowerCase()))

  check('[Coach Feedback] search narrows the list',
    matchedNotes.length > 0 && matchedNotes.length < feedbackBefore.rows && allMatched,
    `typed="${term}" rows ${feedbackBefore.rows} -> ${matchedNotes.length}, every row contains it=${allMatched}, range=${narrowed.range}`)
  await box.fill('')
  await page.waitForTimeout(500)
}

// ---- attendance / predictions / notifications lists ---------------------
// These three were the last hand-rolled tables in the app: a plain `<table>`
// with no pager, no search and no `#` column, and - the part that actually hid
// the bug - an auto-height page under `main`'s `overflow-hidden`, so rows past
// the fold were unreachable AND reported no scrollbar. All three now render
// through the same `RecordsTable` the QR and Reports lists use, so they are
// asked the same questions.
console.log('\n--- attendance / predictions / notifications sweep ---')

const RECORD_LISTS = [
  { path: '/attendance', label: 'Attendance' },
  // Predictions and Notifications each open on a view that is NOT the table -
  // "Prediction History" and "Announcements" respectively - so this sweep has to
  // click into the list view first, the same way the /qr sweep below opens
  // Pending before it can read row actions. Without the `tab` key these two
  // would measure a landing render with no table on it and fail on a page that
  // is behaving exactly as designed.
  { path: '/predictions', label: 'Predictions', tab: 'Recent Predictions' },
  { path: '/notifications', label: 'Notifications', tab: 'Recent Notifications' },
]

/** Total out of a "Showing 1-N of T records" footer, or null. */
const totalOf = (range) => {
  const m = range && range.match(/of ([\d,]+) records/)
  return m ? Number(m[1].replace(/,/g, '')) : null
}

/**
 * The most recent date that actually has check-ins, as a YYYY-MM-DD civil date.
 *
 * The gate needs a day with rows in it, and there is no safe way to guess one:
 * the page defaults to TODAY, but the seeded window ends when it was seeded
 * (`asOf`), so the wall clock eventually walks past the data entirely. This gate
 * used to hardcode "seven days back", which was wrong twice over - seven days
 * before a Sunday is a Sunday, and the dataset models a Mon-Sat gym so Sundays
 * are legitimately empty - and it was ALSO wrong simply because the clock had
 * since moved past the end of the window. It failed on 2026-10-04, the second
 * day past the dataset's own `asOf`, and read that empty day as a broken table.
 *
 * Asking the database removes the guesswork: the answer stays correct however
 * long ago the demo data was seeded, and it skips Sundays for free because a
 * closed day has no rows to return. Falls back to "yesterday" if the query
 * fails, so a network blip degrades the check rather than killing the run.
 */
async function latestAttendanceDay() {
  try {
    const { createClient } = await import('@supabase/supabase-js')
    const supabase = createClient(env.VITE_SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    })
    const { data, error } = await supabase
      .from('attendance')
      .select('check_in_date')
      .order('check_in_date', { ascending: false })
      .limit(1)
    if (error || !data?.length) throw new Error(error?.message ?? 'no rows')
    return data[0].check_in_date
  } catch (err) {
    console.warn(`  warn  could not read the latest attendance day (${err.message}); falling back to yesterday`)
    const d = new Date(Date.now() - 86400000)
    return d.toISOString().slice(0, 10)
  }
}

/**
 * Set the page's date-range chip to an exact window and apply it.
 *
 * The chip is a POPOVER: its start/end inputs only exist in the DOM once the
 * pill is open, so there is no bare `input[type=date]` sitting on the page to
 * `fill()` the way there was before the calendar was wrapped in a chip. Every
 * caller that needs a specific day has to open the thing first, and forgetting
 * that is how a sweep ends up asserting against today's (legitimately empty)
 * window and calling a working page broken.
 */
async function setRangeTo(page, start, end) {
  const chip = page.locator('main button[aria-haspopup="dialog"]').first()
  if (!(await chip.count())) return false
  await chip.click()
  const dialog = page.locator('main [role="dialog"][aria-label="Choose a date range"]')
  if (!(await dialog.count())) return false
  const inputs = dialog.locator('input[type=date]')
  await inputs.nth(0).fill(start)
  await inputs.nth(1).fill(end)
  await dialog.getByRole('button', { name: 'Apply range' }).click()
  await page.waitForTimeout(400)
  return true
}

const OPEN_DAY = await latestAttendanceDay()

for (const list of RECORD_LISTS) {
  await page.goto(`${BASE}${list.path}`, { waitUntil: 'networkidle' })
  await page.waitForTimeout(2500)

  // The attendance page defaults to TODAY, and the seeded window ends whenever it
  // was seeded - so "today" is legitimately an empty day and the list correctly
  // says so. Asserting "rows > 1" there would be asserting that the demo data is
  // fresh. OPEN_DAY is the most recent day the database actually has rows for.
  if (list.path === '/attendance') {
    // Same OPEN_DAY step-back as before, now THROUGH the popover: the picker is
    // a chip whose inputs only exist while it is open, so the bare-input `fill`
    // this used to do no longer matches anything and the sweep would read the
    // empty "today" and report a working table as broken.
    await setRangeTo(page, OPEN_DAY, OPEN_DAY)
    await page.waitForTimeout(2000)
  }

  // Open the view that carries the table. `exact: true` matters here: the
  // notifications tab strip is "Announcements | Recent Notifications" and
  // "Notifications" alone would be a substring of the second one, so an
  // unanchored match could resolve to the wrong tab (or to two).
  if (list.tab) {
    const tab = page.getByRole('tab', { name: list.tab, exact: true })
    if (await tab.count()) {
      await tab.first().click()
      await page.waitForTimeout(1200)
    }
  }

  const read = await readRecords()
  const total = totalOf(read.range)
  check(`[${list.label}] the list is paged`,
    total !== null && total > 0 && /^Showing 1\u2013/.test(read.range ?? '')
    && /^\d+ \/ \d+$/.test(read.page ?? ''),
    `rows=${read.rows} range=${read.range} page=${read.page}`)
  // The assertion that matters: a body that overflows its own card is a page
  // whose rows are cut in half with no scrollbar, which is the failure mode
  // this sweep exists for.
  check(`[${list.label}] the table body does not scroll`, read.overflow <= 2,
    `overflow=${read.overflow}px rowHeight=${read.rowHeight}px clientH=${read.clientH} scrollH=${read.scrollH}`)
  // The row height ITSELF, which the overflow check cannot catch. A body that
  // does not scroll can still be a mis-measured one: a page that happens to
  // show nine rows has ~190px of slack, so a page size that is too large by a
  // few pixels a row never shows up as an overflow - it stays invisible until
  // the data grows. `RecordsTable` budgets 44px a row and the `tr` carries its
  // own 1px rule, so 44-46 is the honest band.
  check(`[${list.label}] every row is the height the page size assumes`,
    read.rowHeight >= 44 && read.rowHeight <= 46,
    `rowHeight=${read.rowHeight}px (budget 44px + 1px rule)`)
  check(`[${list.label}] the row index is a column of its own`,
    read.heads[0] === '#', JSON.stringify(read.heads))

  if (read.firstName && total !== null && total > 0) {
    const term = read.firstName.slice(0, 20)
    const box = page.getByRole('searchbox').first()
    await box.click()
    await box.fill(term)
    await page.waitForTimeout(700)
    const narrowed = await readRecords()
    const after = totalOf(narrowed.range) ?? 0
    // "Fewer records", not "exactly one". A broadcast notification's TITLE is
    // shared by every recipient it went to, so typing one into the search
    // legitimately returns many rows; what has to be true is that the result
    // set shrank, which is what a debounce that never fires would not do.
    check(`[${list.label}] search narrows the list`,
      narrowed.rows > 0 && (after === 1 || after < total),
      `typed="${term}" ${total} -> ${after} records (${narrowed.range})`)
    await box.fill('')
    await page.waitForTimeout(400)
  } else {
    check(`[${list.label}] search narrows the list`, false, `nothing to search by (rows=${read.rows} range=${read.range})`)
  }
}

// ---- predictions: the date filter belongs to the Recent list --------------
// It used to be shown on BOTH tabs, which was defensible only while the two
// Generate KPI cards counted the same range-filtered query. They now report the
// whole table instead, so a chip sitting beside them would filter a list that
// is not on screen and move nothing - it would look load-bearing and be inert.
// Hence Recent-only, the same rule Notifications follows.
const totalOn = () => page.evaluate(() => {
  const card = [...document.querySelectorAll('main .glass-card')]
    .find(c => /Total Predictions/.test(c.innerText))
  const m = card?.innerText.match(/(\d+)/)
  return m ? Number(m[1]) : null
})
await page.goto(`${BASE}/predictions`, { waitUntil: 'networkidle' })
await page.waitForTimeout(2500)
// Generate is the landing view, so the chip must be absent on first paint.
const genChips = await page.locator('main button[aria-haspopup="dialog"]').count()
const genBefore = await totalOn()
await page.getByRole('tab', { name: 'Recent Predictions', exact: true }).click()
await page.waitForTimeout(1200)
const recentChips = await page.locator('main button[aria-haspopup="dialog"]').count()
await setRangeTo(page, OPEN_DAY, OPEN_DAY)
await page.waitForTimeout(1500)
// Back to Generate, where the chip is gone. The headline count must be exactly
// what it was before the window was narrowed: an admin cannot undo a filter
// they cannot see, so the numbers must not move underneath them.
await page.getByRole('tab', { name: 'Generate', exact: true }).click()
await page.waitForTimeout(2000)
const genAfter = await totalOn()
check('[Predictions] the date filter is shown on the Recent tab only',
  genChips === 0 && recentChips === 1, `generate=${genChips} recent=${recentChips}`)
check('[Predictions] narrowing the Recent window leaves the Generate totals alone',
  genBefore != null && genAfter === genBefore,
  `total ${genBefore} -> ${genAfter} after filtering Recent to ${OPEN_DAY}`)

// The attendance page carries its own Members/Trainers tabs, and both are the
// same list - so page 3 of the member view must not open as page 3 of the
// (shorter) trainer view. That is what the `key` on the table is for.
await page.goto(`${BASE}/attendance`, { waitUntil: 'networkidle' })
await page.waitForTimeout(2000)
// Same OPEN_DAY step-back as above: on an empty "today" both tabs read as empty
// and the assertion below would pass for the wrong reason.
const sameDayApplied = await setRangeTo(page, OPEN_DAY, OPEN_DAY)
check('[Attendance] the date chip can be opened and set to an exact day',
  sameDayApplied, 'the range chip or its popover is not reachable from the toolbar')
const trainerTab = page.getByRole('button', { name: 'Trainers', exact: true })
if (await trainerTab.count()) {
  await trainerTab.first().click()
  await page.waitForTimeout(1500)
  const trainers = await readRecords()
  check('[Attendance] the trainers tab is its own list, starting at page 1',
    trainers.range === null || /^Showing 1\u2013/.test(trainers.range),
    `range=${trainers.range} page=${trainers.page} heads=${JSON.stringify(trainers.heads)}`)
} else {
  check('[Attendance] the trainers tab is its own list, starting at page 1', false, 'no trainers tab')
}

// ---- trainer detail: paged Assigned Members / Recent Feedback ------------
// This route is not in ROUTES: its path needs a real trainer id, and the
// numbers it has to agree with live only in the database. So the trainer is
// picked at runtime (busiest by feedback, so the feedback tab really has a
// second page to turn) and every count below is compared against what the
// database says, never against a literal copied from a past run.
console.log('\n--- trainer detail sweep ---')

let detailTrainer = null
let pickError = null
let memberTotal = 0
let assignedEmails = []
try {
  const { createClient } = await import('@supabase/supabase-js')
  const db = createClient(env.VITE_SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  const [{ data: assigns, error: aErr }, { data: fbs, error: fErr }, { data: trainers, error: tErr }] = await Promise.all([
    db.from('trainer_assignments').select('trainer_id, member_id, status'),
    db.from('trainer_feedback').select('trainer_id, rating'),
    db.from('profiles').select('id, full_name').eq('role', 'trainer'),
  ])
  if (aErr || fErr || tErr) throw new Error(aErr?.message ?? fErr?.message ?? tErr?.message)
  const assigned = new Map()
  for (const a of assigns ?? []) {
    if (a.status === 'active') assigned.set(a.trainer_id, (assigned.get(a.trainer_id) ?? 0) + 1)
  }
  const fb = new Map()
  const rated = new Map()
  for (const f of fbs ?? []) {
    fb.set(f.trainer_id, (fb.get(f.trainer_id) ?? 0) + 1)
    if (f.rating != null) rated.set(f.trainer_id, (rated.get(f.trainer_id) ?? 0) + 1)
  }
  detailTrainer = (trainers ?? [])
    .filter(t => (assigned.get(t.id) ?? 0) > 0 && (fb.get(t.id) ?? 0) > 0)
    .map(t => ({ id: t.id, name: t.full_name, assigned: assigned.get(t.id) ?? 0, feedback: fb.get(t.id) ?? 0, rated: rated.get(t.id) ?? 0 }))
    .sort((x, y) => (y.feedback - x.feedback) || (y.assigned - x.assigned))[0] ?? null
  if (detailTrainer) {
    const { count } = await db.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'member')
    memberTotal = count ?? 0
    const { data: mine, error: mErr } = await db
      .from('trainer_assignments')
      .select('member_id')
      .eq('trainer_id', detailTrainer.id)
      .eq('status', 'active')
    if (mErr) throw new Error(mErr.message)
    const ids = (mine ?? []).map(a => a.member_id)
    const { data: mails, error: eErr } = await db.from('profiles').select('email').in('id', ids)
    if (eErr) throw new Error(eErr.message)
    assignedEmails = (mails ?? []).map(r => r.email).filter(Boolean)
  }
} catch (err) {
  detailTrainer = null
  pickError = err.message
}

if (!detailTrainer) {
  check('[Trainer Detail] a trainer with assignments and feedback exists', false, pickError ?? 'none in the database')
} else {
  // The contract under test: DETAIL_PAGE_SIZE rows a page, the records footer
  // inside the card, and the tab badge printing the REAL total - the feedback
  // badge used to print 10 (the old .limit(10)) whatever the truth was.
  //
  // Ten, not the app-wide LIST_PAGE_SIZE of fifteen: the detail page is the one
  // list with its own density (see DETAIL_PAGE_SIZE in TrainerDetailPage), so it
  // is asserted against ten. This constant is local to this block - the members,
  // trainers and memberships sweeps above carry their own 15 and are unaffected.
  const PAGE = 10
  const tr = detailTrainer
  const expectMembersRows = Math.min(PAGE, tr.assigned)
  const expectFeedbackRows = Math.min(PAGE, tr.feedback)
  const expectFeedbackPages = Math.max(1, Math.ceil(tr.feedback / PAGE))

  consoleErrors = []
  failedResponses = []
  await page.goto(`${BASE}/trainers/${tr.id}`, { waitUntil: 'networkidle' })
  await page.waitForTimeout(2500)

  const readDetail = () => page.evaluate(() => {
    const text = document.body.innerText
    const badges = {}
    for (const tab of document.querySelectorAll('[role="tab"]')) {
      // Tab labels carry the count hard against the label ("Recent
      // Feedback20"): JSX drops the whitespace between the expression and the
      // span, the visible gap is a margin. Split on the trailing digits then.
      const m = tab.innerText.trim().match(/^([\s\S]*?)(\d+)$/)
      if (m) badges[m[1].trim()] = Number(m[2])
    }
    const table = document.querySelector('main table')
    const scroller = table?.closest('.overflow-auto')
    return {
      rows: document.querySelectorAll('main tbody tr').length,
      range: text.match(/Showing ([\d,]+)–([\d,]+) of ([\d,]+) records/)?.[0] ?? null,
      // The pager numbers, matched the same way the list sweeps match them:
      // digits, space, slash, digits. The rating summary renders `4.6/ 5` with
      // no space before the slash, so it can never match this pattern.
      page: text.match(/\b(\d+ \/ \d+)\b/)?.[1] ?? null,
      badges,
      heads: [...document.querySelectorAll('main thead th')].map(th => th.innerText.trim()),
      firstIndex: document.querySelector('main tbody tr td:first-child')?.innerText?.trim() ?? null,
      bodyScroll: scroller ? scroller.scrollHeight - scroller.clientHeight : -1,
      docScroll: document.documentElement.scrollHeight - document.documentElement.clientHeight,
    }
  })

  const landing = await readDetail()
  check('[Trainer Detail] members tab pages against the database total',
    landing.rows === expectMembersRows
    && landing.range === `Showing 1–${expectMembersRows} of ${tr.assigned} records`
    && landing.page === `1 / ${Math.max(1, Math.ceil(tr.assigned / PAGE))}`
    && landing.badges['Assigned Members'] === tr.assigned
    && landing.heads[0] === '#',
    `rows=${landing.rows} range=${landing.range} page=${landing.page} badge=${landing.badges['Assigned Members']} want=${tr.assigned}`)
  check('[Trainer Detail] the members table fits its page without scrolling',
    landing.bodyScroll <= 2, `bodyScroll=${landing.bodyScroll}px`)

  await page.getByRole('button', { name: /Assign Member/ }).click()
  await page.waitForTimeout(2500)
  const drawer = await page.evaluate(() => {
    // Anchor on the slide-in panel, NOT on `div.fixed.inset-0` + text: other
    // fixed wrappers can contain the whole page (and the members table prints
    // assigned emails), which made a correctly filtered drawer look like it
    // leaked an assigned member. The leak test reads the scrollable list only.
    const panel = document.querySelector('.slide-in-right')
    if (!panel) return null
    const list = panel.querySelector('.flex-1')
    const offers = [...panel.querySelectorAll('button')]
      .map(b => b.innerText.split('\n').find(l => /\S+@\S+/.test(l)) ?? '')
      .filter(Boolean)
    return { offers, text: (list ?? panel).innerText }
  })
  check('[Trainer Detail] the assign drawer offers exactly the unassigned members',
    drawer !== null && drawer.offers.length === memberTotal - tr.assigned,
    `offers=${drawer?.offers.length} want=${memberTotal - tr.assigned}`)
  // The drawer used to filter the PAGED table - one page of rows - so every
  // already-assigned member from page 2 onwards was offered again as if free.
  // Matched as EXACT emails: `new.member2@mock.fit` contains `member2@mock.fit`,
  // and a substring scan called a correctly filtered drawer a leak. An offer
  // line is the bare email followed by the member code.
  const offered = drawer
    ? drawer.offers.map(o => (o.match(/^\S+@\S+/) ?? [o])[0])
    : []
  const leaked = assignedEmails.filter(e => offered.includes(e))
  check('[Trainer Detail] the assign drawer never offers an already-assigned member',
    drawer !== null && leaked.length === 0, `leaked=${leaked.slice(0, 3).join(', ')}`)
  await page.locator('.slide-in-right button').first().click()
  await page.waitForTimeout(500)

  await page.getByRole('tab', { name: /Recent Feedback/ }).click()
  await page.waitForTimeout(1500)
  const feedback1 = await readDetail()
  check('[Trainer Detail] feedback tab pages against the database total',
    feedback1.rows === expectFeedbackRows
    && feedback1.range === `Showing 1–${expectFeedbackRows} of ${tr.feedback} records`
    && feedback1.page === `1 / ${expectFeedbackPages}`
    && feedback1.badges['Recent Feedback'] === tr.feedback,
    `rows=${feedback1.rows} range=${feedback1.range} page=${feedback1.page} badge=${feedback1.badges['Recent Feedback']} want=${tr.feedback}`)

  if (expectFeedbackPages > 1) {
    await page.getByRole('button', { name: 'Next page' }).click()
    await page.waitForTimeout(900)
    const feedback2 = await readDetail()
    check('[Trainer Detail] the feedback tail is reachable and indexed',
      feedback2.rows === tr.feedback - PAGE
      && feedback2.range === `Showing ${PAGE + 1}–${tr.feedback} of ${tr.feedback} records`
      && feedback2.page === `2 / ${expectFeedbackPages}`
      && feedback2.firstIndex === String(PAGE + 1),
      `rows=${feedback2.rows} range=${feedback2.range} page=${feedback2.page} first#=${feedback2.firstIndex}`)
  }

  if (tr.rated > 0) {
    const ratedShown = await page.evaluate(() => document.body.innerText.match(/(\d+) rated/)?.[1] ?? null)
    check('[Trainer Detail] the rating summary counts every rated row',
      ratedShown !== null && Number(ratedShown) === tr.rated, `shown=${ratedShown} want=${tr.rated}`)
  }

  const dirtyConsole = consoleErrors.filter(e => !/status of 404/.test(e))
  check('[Trainer Detail] no console errors or failed requests',
    dirtyConsole.length === 0 && failedResponses.length === 0,
    `${dirtyConsole.length} console / ${failedResponses.length} http: ${dirtyConsole[0] ?? failedResponses[0]?.url ?? ''}`)
  check('[Trainer Detail] the page itself does not scroll',
    landing.docScroll <= 0, `docScroll=${landing.docScroll}px`)
}

// ---- no-scroll sweep -----------------------------------------------------
// Task 11 proved this for the dashboard; the list pages are the ones this plan
// rebuilt, so they get the same treatment. /qr is here because it used to be
// the one page with an auto-height body under `main`'s overflow-hidden: with 55
// enrolment rows it simply ran off the bottom of the viewport, and a clipped
// page reports no scrollbar, so only the clipping assertion can catch it.
// The two reports pages joined them in the same sweep: both used to be
// auto-height stacks under that same `overflow-hidden` main.
console.log('\n--- no-scroll sweep ---')
for (const vp of VIEWPORTS) {
  await page.setViewportSize({ width: vp.w, height: vp.h })
  for (const route of ROUTES.filter(r => ['/members', '/trainers', '/memberships', '/qr', '/reports/inactive', '/reports/feedback', '/attendance', '/predictions', '/notifications'].includes(r.path))) {
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
