import { chromium } from 'playwright'
import { mkdirSync } from 'fs'

const url = 'http://localhost:5173'
const shots = 'C:\\capshii\\capshii\\admin\\screenshots'
mkdirSync(shots, { recursive: true })

async function run() {
  const browser = await chromium.launch()
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } })
  const errors = []
  page.on('pageerror', e => errors.push(String(e)))

  await page.goto(url, { waitUntil: 'networkidle' })
  const email = page.locator('input[type=email]')
  if (await email.count()) {
    await email.fill('admin@fitness.com')
    await page.locator('input[type=password]').fill('Admin123!')
    await page.locator('button[type=submit], button:has-text("Sign In"), button:has-text("Login")').first().click()
    await page.waitForURL('**/dashboard', { timeout: 15000 })
  }
  await page.waitForTimeout(2500)

  const dailyPanel = page.locator('.glass-card').filter({ hasText: 'Daily Check-ins' }); const xTicks = await dailyPanel.locator('.recharts-cartesian-axis.xAxis .recharts-cartesian-axis-tick-value').allTextContents()
  console.log('daily x ticks (should end with D):', xTicks.slice(0, 4), '...', xTicks.slice(-2))
  console.log('daily D-ticks OK:', xTicks.length > 10 && xTicks.every(t => /^\d+D$/.test(t)))

  const growthPanel = page.locator('.glass-card').filter({ hasText: 'Member Growth Over Time' })
  const growthTicks = await growthPanel.locator('.recharts-cartesian-axis.xAxis .recharts-cartesian-axis-tick-value').allTextContents()
  console.log('growth month ticks:', growthTicks)
  console.log('month ticks OK:', growthTicks.length > 0 && growthTicks.every(t => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'].includes(t)))

  const totalLabels = await growthPanel.locator('.recharts-label-list text').allTextContents()
  console.log('bar totals (LabelList):', totalLabels)
  console.log('totals OK:', totalLabels.length >= 2 && totalLabels.every(v => /^\d+$/.test(v)))

  const legendChips = await growthPanel.locator('.glass-card .flex.gap-4 span').count()
  console.log('growth legend chips present:', (await growthPanel.innerText()).includes('New') && (await growthPanel.innerText()).includes('Existing'))

  const genderPanel = page.locator('.glass-card').filter({ hasText: 'Gender Distribution' })
  const donut = genderPanel.locator('.recharts-pie-sector').first()
  const legendRow = genderPanel.locator('div.flex.flex-col.gap-3\\.5')
  if (await donut.count() && await legendRow.count()) {
    const db = await donut.boundingBox()
    const lb = await legendRow.boundingBox()
    console.log('donut box:', db && Math.round(db.x), '| legend box:', lb && Math.round(lb.x))
    console.log('side-by-side OK:', db && lb && lb.x > db.x + db.width - 40 && Math.abs((db.y + db.height / 2) - (lb.y + lb.height / 2)) < 120)
  } else {
    console.log('donut/legend locators not found')
  }
  const legendText = await genderPanel.innerText()
  console.log('gender legend has %:', /%\s*$|%\n/.test(legendText), '| exact counts:', (legendText.match(/\d+/g) || []).length >= 3)

  await page.screenshot({ path: `${shots}\\dashboard.png` })
  console.log('PAGE ERRORS:', errors.length ? errors : 'none')
  await browser.close()
}

run().catch(e => { console.error(e); process.exit(1) })
