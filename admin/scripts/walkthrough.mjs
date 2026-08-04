import { chromium } from 'playwright'
import { mkdirSync } from 'fs'

const SHOTS = 'C:/WINDOWS/TEMP/opencode/shots'
mkdirSync(SHOTS, { recursive: true })

const screens = [
  { path: '/dashboard', expect: ['Total Members', 'Attendance Today', 'Daily Check-ins'] },
  { path: '/members', expect: ['Juan Dela Cruz', 'Maria Santos'] },
  { path: '/trainers', expect: ['Coach Ramil', 'Coach Aira'] },
  { path: '/memberships', expect: ['Daily', 'Monthly'] },
  { path: '/attendance', expect: ['Daily', 'Monthly'] },
  { path: '/workouts', expect: ['Bench Press'] },
  { path: '/reports', expect: ['Reports'] },
  { path: '/predictions', expect: ['Prediction'] },
  { path: '/notifications', expect: ['Notification'] },
  { path: '/settings', expect: ['Settings'] },
]

const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } })
const consoleErrors = []
page.on('pageerror', (e) => consoleErrors.push(`PAGEERROR: ${e.message}`))
page.on('console', (m) => { if (m.type() === 'error') consoleErrors.push(`CONSOLE: ${m.text()}`) })

const results = []

await page.goto('http://localhost:5173')
await page.waitForTimeout(2500)
await page.locator('input[type=email]').fill('admin@fitness.com')
await page.locator('input[type=password]').fill('Admin123!')
await page.locator('button[type=submit]').click()
try {
  await page.waitForSelector('text=Total Members', { timeout: 10000 })
  console.log('LOGIN OK')
} catch {
  console.log('LOGIN FAILED, body:', (await page.locator('body').innerText()).slice(0, 200))
  process.exit(1)
}

for (const s of screens) {
  consoleErrors.length = 0
  await page.goto(`http://localhost:5173${s.path}`)
  let rendered = false
  try {
    await page.waitForSelector(`text=${s.expect[0]}`, { timeout: 10000 })
    rendered = true
  } catch { /* fallthrough */ }
  await page.waitForTimeout(2000)
  const text = await page.locator('body').innerText()
  const missing = s.expect.filter((k) => !text.includes(k))
  const errs = consoleErrors.filter((e) => !e.includes('ERR_ABORTED'))
  await page.screenshot({ path: `${SHOTS}/screen_${s.path.replaceAll('/', '_')}.png`, fullPage: true })
  results.push({ route: s.path, rendered, missing, consoleErrors: errs, bodyChars: text.length })
}

await page.goto('http://localhost:5173/qr')
await page.waitForTimeout(3000)
const qrText = await page.locator('body').innerText()
await page.screenshot({ path: `${SHOTS}/screen__qr.png`, fullPage: true })
results.push({ route: '/qr', rendered: qrText.length > 100, missing: [], consoleErrors: [], bodyChars: qrText.length })

await browser.close()
for (const r of results) console.log(JSON.stringify(r))
