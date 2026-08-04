import { chromium } from 'playwright'

const browser = await chromium.launch()
const page = await browser.newPage()
page.on('pageerror', (e) => console.log(`PAGEERROR: ${e.message}`))
page.on('console', (m) => { if (m.type() === 'error') console.log(`CONSOLE: ${m.text()}`) })
page.on('requestfailed', (r) => console.log(`REQFAIL: ${r.url()} ${r.failure()?.errorText}`))

await page.goto('http://localhost:5173')
await page.waitForLoadState('networkidle')
console.log('inputs:', await page.locator('input').count(), 'buttons:', await page.locator('button').count())
await page.locator('input[type=email]').fill('admin@fitness.com')
await page.locator('input[type=password]').fill('Admin123!')
await page.locator('button[type=submit]').click()
await page.waitForTimeout(4000)
console.log('URL:', page.url())
console.log('BODY:', (await page.locator('body').innerText()).slice(0, 300))
await page.screenshot({ path: 'C:/WINDOWS/TEMP/opencode/shots/login_debug.png' })
await browser.close()
