import { chromium } from 'playwright'

const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } })
await page.goto('http://localhost:5173')
await page.waitForTimeout(2500)
await page.locator('input[type=email]').fill('admin@fitness.com')
await page.locator('input[type=password]').fill('Admin123!')
await page.locator('button[type=submit]').click()
await page.waitForSelector('text=Total Members', { timeout: 10000 })

for (const path of ['/attendance', '/reports', '/predictions', '/settings']) {
  await page.goto(`http://localhost:5173${path}`)
  await page.waitForTimeout(4000)
  const text = (await page.locator('body').innerText()).slice(0, 800)
  console.log(`===== ${path} =====`)
  console.log(text)
  console.log()
}
await browser.close()
