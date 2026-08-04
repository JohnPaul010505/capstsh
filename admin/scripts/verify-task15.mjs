import { chromium } from 'playwright'

const url = 'http://localhost:5173'

async function run() {
  const browser = await chromium.launch()
  const page = await browser.newPage()
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

  await page.waitForTimeout(2000)
  const body = await page.locator('body').innerText()
  console.log('panel headers present:', {
    expiring: body.includes('Expiring Members'),
    next7: body.includes('Next 7 days'),
    checkins: body.includes("Today's Check-ins"),
  })
  const tableCount = await page.locator('table').count()
  console.log('tables on /dashboard:', tableCount)
  const expiringTable = page.locator('table').filter({ hasText: 'Days left' })
  if (await expiringTable.count()) {
    const txt = (await expiringTable.innerText()).split('\n').filter(Boolean)
    console.log('expiring rows:', txt.join(' | '))
  }
  const renewButtons = await page.locator('button:has-text("Renew")').count()
  console.log('Renew buttons:', renewButtons)
  if (renewButtons > 0) {
    await page.locator('button:has-text("Renew")').first().click()
    await page.waitForURL('**/members/**', { timeout: 10000 })
    console.log('Renew navigated to:', page.url().split('/').pop())
  }
  console.log('PAGE ERRORS:', errors.length ? errors : 'none')
  await browser.close()
}

run().catch(e => { console.error(e); process.exit(1) })
