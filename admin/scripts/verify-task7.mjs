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

  await page.goto(url + '/reports', { waitUntil: 'networkidle' })
  await page.waitForTimeout(1800)

  const tables = page.locator('table')
  const count = await tables.count()
  console.log('tables on /reports:', count)
  for (let i = 0; i < count; i++) {
    const t = tables.nth(i)
    const txt = (await t.innerText()).split('\n').filter(Boolean)
    console.log(`--- table ${i} (${txt.length} cells) ---`)
    console.log(txt.slice(0, 24).join(' | '))
  }

  const body = await page.locator('body').innerText()
  console.log('\nempty-state strings:', {
    noExpiring: body.includes('No memberships expiring soon'),
    noInactive: body.includes('No inactive members'),
  })
  console.log('PAGE ERRORS:', errors.length ? errors : 'none')
  await browser.close()
}

run().catch(e => { console.error(e); process.exit(1) })
