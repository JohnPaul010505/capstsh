import { chromium } from 'playwright'
import { config } from 'dotenv'
import { createClient } from '@supabase/supabase-js'

config({ path: 'C:/capshii/capshii/admin/.env' })
const sc = createClient(process.env.VITE_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})
const { data: m } = await sc.from('profiles').select('id,full_name').eq('role', 'member').eq('email', 'member1@mock.fit').single()
const { data: t } = await sc.from('profiles').select('id,full_name').eq('role', 'trainer').eq('email', 'trainer1@mock.fit').single()

const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } })
await page.goto('http://localhost:5173')
await page.waitForTimeout(2500)
await page.locator('input[type=email]').fill('admin@fitness.com')
await page.locator('input[type=password]').fill('Admin123!')
await page.locator('button[type=submit]').click()
await page.waitForSelector('text=Total Members', { timeout: 10000 })

await page.goto(`http://localhost:5173/members/${m.id}`)
await page.waitForTimeout(4000)
console.log(`===== member detail: ${m.full_name} =====`)
console.log((await page.locator('body').innerText()).slice(0, 1000))
await page.screenshot({ path: 'C:/WINDOWS/TEMP/opencode/shots/member_detail.png', fullPage: true })

await page.goto(`http://localhost:5173/trainers/${t.id}`)
await page.waitForTimeout(4000)
console.log(`===== trainer detail: ${t.full_name} =====`)
console.log((await page.locator('body').innerText()).slice(0, 1000))
await page.screenshot({ path: 'C:/WINDOWS/TEMP/opencode/shots/trainer_detail.png', fullPage: true })

await browser.close()
