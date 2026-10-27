#!/usr/bin/env node
// The newest October member must be at the end of the Members list, even
// when the member number grows from three digits to four.
import assert from 'node:assert/strict'
import { fileURLToPath } from 'node:url'
import dotenv from 'dotenv'
import { chromium } from 'playwright'
import { createClient } from '@supabase/supabase-js'

dotenv.config({ path: fileURLToPath(new URL('../.env', import.meta.url)), quiet: true })

const db = createClient(
  process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { autoRefreshToken: false, persistSession: false } },
)
const { data: newest, count, error } = await db.from('profiles')
  .select('code', { count: 'exact' })
  .eq('role', 'member')
  .gte('created_at', '2026-09-30T16:00:00Z')
  .lte('created_at', '2026-10-26T15:59:59.999Z')
  .order('created_at', { ascending: false })
  .order('id', { ascending: false })
  .limit(1)
if (error) throw error
assert.ok(count > 1, 'October member records are needed for the ordering check')

const browser = await chromium.launch()
try {
  const page = await browser.newPage({ timezoneId: 'Asia/Manila' })
  await page.goto('http://127.0.0.1:5173/login')
  await page.locator('input[type=email]').fill(process.env.ADMIN_EMAIL)
  await page.locator('input[type=password]').fill(process.env.ADMIN_PASSWORD)
  await page.getByRole('button', { name: /sign in|log ?in/i }).first().click()
  await page.waitForURL(url => !url.pathname.includes('/login'))

  await page.goto('http://127.0.0.1:5173/members')
  await page.getByRole('button', { name: /Date range:/ }).click()
  await page.getByLabel('Start date').fill('2026-10-01')
  await page.getByLabel('End date').fill('2026-10-26')
  await page.getByRole('button', { name: 'Apply range' }).click()
  await page.getByText(new RegExp(`of ${count} records`)).waitFor()
  for (let current = 1; current < Math.ceil(count / 15); current++) {
    await page.getByRole('button', { name: 'Next page' }).click()
    await page.getByText(new RegExp(`${current + 1} / ${Math.ceil(count / 15)}`)).waitFor()
  }

  const lastCode = await page.locator('section[aria-label="Members"] tbody tr').last().locator('td').nth(2).innerText()
  assert.equal(lastCode, newest[0].code, `Newest member should be last; found ${lastCode}`)
  console.log('PASS: newest member appears last in the October Members list')
} finally {
  await browser.close()
}
