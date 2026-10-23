import { chromium } from 'playwright'
import { config } from 'dotenv'
import assert from 'node:assert/strict'
import { mkdirSync } from 'node:fs'
config({ quiet: true })
const browser = await chromium.launch({ headless: true })
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } })
const errors = []
page.on('pageerror', e => errors.push(e.message))
mkdirSync('screenshots/page-tabs', { recursive: true })
try {
  await page.goto('http://127.0.0.1:5173/login')
  await page.locator('input[type=email]').fill(process.env.ADMIN_EMAIL)
  await page.locator('input[type=password]').fill(process.env.ADMIN_PASSWORD)
  await page.getByRole('button', { name: /sign in/i }).click()
  await page.waitForURL(url => !url.pathname.includes('login'), { timeout: 60000 })
  for (const route of ['members', 'qr', 'attendance', 'reports/inactive', 'predictions', 'notifications']) {
    await page.goto(`http://127.0.0.1:5173/${route}`)
    if (route === 'notifications') await page.getByRole('tab', { name: 'Recent Notifications' }).click()
    const tabs = page.locator('.page-tabs')
    await tabs.waitFor()
    assert.ok(await tabs.locator('.page-tab').count() >= 2)
    await tabs.locator('.page-tab').last().click()
    assert.equal(await tabs.locator('.page-tab').last().evaluate(el => el.getAttribute('aria-selected') ?? el.getAttribute('aria-pressed')), 'true')
    for (const light of [false, true]) {
      await page.evaluate(light => {
        document.documentElement.classList.toggle('theme-light', light)
        document.documentElement.classList.toggle('theme-dark', !light)
      }, light)
      await page.waitForFunction(() => getComputedStyle(document.querySelector('.page-tab[aria-selected=true], .page-tab[aria-pressed=true]')).backgroundColor === 'rgb(124, 58, 237)')
      const styles = await tabs.evaluate(el => {
        const selected = el.querySelector('[aria-selected=true], [aria-pressed=true]')
        return { padding: getComputedStyle(el).padding, radius: getComputedStyle(el).borderRadius, selected: getComputedStyle(selected).backgroundColor }
      })
      assert.deepEqual(styles, { padding: '4px', radius: '12px', selected: 'rgb(124, 58, 237)' })
      await page.screenshot({ path: `screenshots/page-tabs/${route.replace('/', '-')}-${light ? 'light' : 'dark'}.png` })
      console.log('PASS', route, light ? 'light' : 'dark', 'glass tabs and selection')
    }
  }
  for (const route of ['dashboard', 'reports/generate', 'members', 'attendance', 'notifications']) {
    await page.goto(`http://127.0.0.1:5173/${route}`)
    if (route === 'notifications') await page.getByRole('tab', { name: 'Recent Notifications' }).click()
    await page.evaluate(() => document.documentElement.classList.add('theme-light'))
    const controls = page.locator('.purple-control')
    await controls.first().waitFor()
    const count = await controls.count()
    assert.ok(count >= (route === 'dashboard' || route === 'reports/generate' ? 2 : 1))
    const colors = await controls.evaluateAll(nodes => nodes.map(node => ({ bg: getComputedStyle(node).backgroundColor, fg: getComputedStyle(node).color })))
    assert.ok(colors.every(c => c.bg === 'rgb(124, 58, 237)' && c.fg === 'rgb(255, 255, 255)'), `${route}: ${JSON.stringify(colors)}`)
    console.log('PASS purple controls', route, count)
  }
  await page.getByRole('button', { name: /date range/i }).click()
  assert.equal(await page.getByRole('dialog').evaluate(el => getComputedStyle(el).backdropFilter), 'blur(24px) saturate(1.6)')
  await page.screenshot({ path: 'screenshots/page-tabs/calendar-light.png' })
  assert.deepEqual(errors, [])
} finally { await browser.close() }
