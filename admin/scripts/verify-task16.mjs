import { chromium } from 'playwright'
import { mkdirSync } from 'fs'

const url = 'http://localhost:5173'
const shots = 'C:\\WINDOWS\\TEMP\\opencode\\glass-shots'
mkdirSync(shots, { recursive: true })

const routes = ['/dashboard', '/members', '/trainers', '/memberships', '/attendance', '/reports', '/reports/feedback', '/predictions', '/notifications', '/settings']

async function run() {
  const browser = await chromium.launch()
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } })
  const errors = []
  page.on('pageerror', e => errors.push(String(e)))

  await page.goto(url, { waitUntil: 'networkidle' })
  await page.screenshot({ path: `${shots}\\login.png` })
  const email = page.locator('input[type=email]')
  if (await email.count()) {
    await email.fill('admin@fitness.com')
    await page.locator('input[type=password]').fill('Admin123!')
    await page.locator('button[type=submit], button:has-text("Sign In"), button:has-text("Login")').first().click()
    await page.waitForURL('**/dashboard', { timeout: 15000 })
  }

  await page.waitForTimeout(2500)
  const glassCount = await page.locator('.glass-card').count()
  console.log('glass-card elements on dashboard:', glassCount)

  const body = await page.locator('body').innerText()
  const order = ['Daily Check-ins', 'Member Growth Over Time', 'Gender Distribution', "Today's Check-ins", 'Expiring Members']
    .map(t => body.indexOf(t))
  console.log('panel order (indexes):', order, order.every((v, i) => i === 0 || v > order[i - 1]) ? 'CORRECT ORDER' : 'WRONG ORDER')

  const rows = await page.locator('table').count()
  console.log('tables:', rows)
  const sideBySide = await page.locator('div.grid > div.glass-card').count()
  console.log('glass cards in grid:', sideBySide)

  const stackedBars = await page.locator('.recharts-bar-rectangle').count()
  console.log('stacked bar rects:', stackedBars)

  const legend = await page.locator('.recharts-wrapper + div').count()
  const genderText = body.includes('Female') && body.includes('Male')
  console.log('gender legend text present:', genderText)

  const todayPanel = body.indexOf("Today's Check-ins")
  const expiringPanel = body.indexOf('Expiring Members')
  console.log('side-by-side (both on same viewport):', (await page.locator('body').innerText()).includes('Expires'))

  await page.screenshot({ path: `${shots}\\dashboard.png` })

  await page.goto(url + '/attendance', { waitUntil: 'networkidle' })
  await page.waitForTimeout(1500)
  const attBody = await page.locator('body').innerText()
  console.log('attendance "Until" text:', attBody.includes('Until'))
  console.log('attendance no "Active" text:', !/\bActive\b/.test(attBody))
  await page.screenshot({ path: `${shots}\\attendance.png` })

  const glassAll = {}
  for (const r of routes) {
    await page.goto(url + r, { waitUntil: 'networkidle' })
    await page.waitForTimeout(1200)
    glassAll[r] = await page.locator('.glass-card').count()
    console.log(`route ${r}: glass=${glassAll[r]}`)
  }

  console.log('PAGE ERRORS:', errors.length ? errors : 'none')
  await browser.close()
}

run().catch(e => { console.error(e); process.exit(1) })
