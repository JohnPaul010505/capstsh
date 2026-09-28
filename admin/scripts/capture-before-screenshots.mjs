import { chromium } from 'playwright'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const envPath = path.resolve(__dirname, '../.env')

function loadEnv() {
  const content = fs.readFileSync(envPath, 'utf8')
  const env = {}
  for (const line of content.split(/\r?\n/)) {
    const m = line.match(/^\s*([^#=]+)=(.*)$/)
    if (m) env[m[1].trim()] = m[2].trim().replace(/^['"]|['"]$/g, '')
  }
  return env
}

const env = loadEnv()
// Verification scripts sign in as the real admin; the credentials live only in
// the git-ignored admin/.env (ADMIN_EMAIL / ADMIN_PASSWORD), never in source —
// a hardcoded password here previously overwrote the admin's actual login.
const adminEmail = env.ADMIN_EMAIL || process.env.ADMIN_EMAIL
const adminPassword = env.ADMIN_PASSWORD || process.env.ADMIN_PASSWORD
if (!adminEmail || !adminPassword) {
  throw new Error('ADMIN_EMAIL / ADMIN_PASSWORD missing from admin/.env')
}
const baseUrl = process.argv[2] || 'http://localhost:5173'
const shotsDir = path.resolve(__dirname, '../screenshots/before')
fs.mkdirSync(shotsDir, { recursive: true })

async function run() {
  console.log('Capturing baseline screenshots from:', baseUrl)
  const browser = await chromium.launch({ headless: true })
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } })

  try {
    // 1. Login
    await page.goto(`${baseUrl}/login`, { waitUntil: 'networkidle' })
    await page.fill('input[type="email"]', adminEmail)
    await page.fill('input[type="password"]', adminPassword)
    await page.click('button[type="submit"]')
    await page.waitForURL('**/dashboard', { timeout: 15000 })
    await page.waitForTimeout(2000)

    // Capture pages
    const routes = [
      { name: '01-dashboard.png', url: '/dashboard' },
      { name: '02-members.png', url: '/members' },
      { name: '03-trainers.png', url: '/trainers' },
      { name: '04-memberships.png', url: '/memberships' },
      { name: '05-qr.png', url: '/qr' },
      { name: '06-attendance.png', url: '/attendance' },
      { name: '07-reports.png', url: '/reports' },
      { name: '08-feedback.png', url: '/reports/feedback' },
      { name: '09-predictions.png', url: '/predictions' },
      { name: '10-notifications.png', url: '/notifications' },
    ]

    for (const r of routes) {
      await page.goto(`${baseUrl}${r.url}`, { waitUntil: 'networkidle' })
      await page.waitForTimeout(1500)
      const target = path.join(shotsDir, r.name)
      await page.screenshot({ path: target })
      console.log(`Saved screenshot: ${r.name}`)
    }

    console.log('Baseline screenshots captured successfully.')
  } finally {
    await browser.close()
  }
}

run().catch(err => {
  console.error(err)
  process.exit(1)
})
