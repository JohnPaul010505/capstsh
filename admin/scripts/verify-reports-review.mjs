import { chromium } from 'playwright'
import { config } from 'dotenv'
import assert from 'node:assert/strict'
import { mkdirSync, readFileSync } from 'node:fs'
config({ quiet: true })
const browser = await chromium.launch({ headless: true })
const page = await browser.newPage({ viewport: { width: 1920, height: 1000 }, timezoneId: 'Asia/Manila' })
const errors = []
page.on('pageerror', e => errors.push(e.message))
page.on('response', async response => { if (response.status() >= 400 && response.url().includes('/rest/')) console.log('DATA ERROR', response.status(), (await response.text()).slice(0, 400)) })
const settle = async () => {
  await page.waitForFunction(() => document.querySelector('tbody tr') && !document.querySelector('tbody')?.textContent.includes('Loading'), { timeout: 90000 })
}
const checkLayout = async label => {
  await settle()
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))))
  const metrics = await page.locator('table').evaluate(table => {
    const box = table.parentElement
    const rows = [...table.querySelectorAll('tbody tr')]
    return { count: rows.length, overflow: box.scrollHeight - box.clientHeight, gap: box.getBoundingClientRect().bottom - table.getBoundingClientRect().bottom, lastVisible: rows.at(-1).getBoundingClientRect().bottom <= box.getBoundingClientRect().bottom + 2 }
  })
  if (metrics.count !== 12) console.log('Unexpected table', await page.locator('tbody').innerText(), page.url())
  assert.equal(metrics.count, 12, `${label}: row count ${JSON.stringify(metrics)}`)
  assert.ok(metrics.overflow <= 2 && metrics.lastVisible, `${label}: clipped/scrolling rows ${JSON.stringify(metrics)}`)
  assert.ok(Math.abs(metrics.gap) <= 3, `${label}: unused space ${JSON.stringify(metrics)}`)
  console.log('PASS layout', label, metrics)
}
try {
  await page.goto('http://127.0.0.1:5173/login')
  await page.locator('input[type=email]').waitFor({ state: 'visible' })
  if (await page.locator('input[type=email]').count()) {
    await page.locator('input[type=email]').fill(process.env.ADMIN_EMAIL)
    await page.locator('input[type=password]').fill(process.env.ADMIN_PASSWORD)
    await page.getByRole('button', { name: /sign in/i }).click()
    await page.waitForURL(url => !url.pathname.includes('login'), { timeout: 60000 })
    await page.goto('http://127.0.0.1:5173/reports/inactive')
  }
  await checkLayout('Inactive')
  const initial = await page.locator('tbody').innerText()
  await page.getByRole('tab', { name: 'Generation Reports' }).click()
  const labels = { inactive: 'Inactive Members & Trainers', feedback: 'Coach Feedback', dailyCheckins: 'Daily Check-ins', revenue: 'Revenue Overview', memberGrowth: 'Member Growth', memberOverview: 'Member Overview', recentActivity: 'Recent Activity' }
  const select = { selectOption: async value => {
    await page.getByRole('combobox', { name: 'Select report type' }).click()
    await page.getByRole('option', { name: labels[value], exact: true }).click()
  } }
  mkdirSync('screenshots/reports-review', { recursive: true })
  for (const light of [false, true]) {
    await page.evaluate(light => document.documentElement.classList.toggle('theme-light', light), light)
    const colors = await page.locator('.purple-control').evaluateAll(elements => elements.map(el => ({ color: getComputedStyle(el).color, bg: getComputedStyle(el).backgroundColor })))
    assert.equal(colors.length, 3)
    assert.ok(colors.every(c => c.color === (light ? 'rgb(36, 18, 55)' : 'rgb(255, 255, 255)')))
    await page.getByRole('combobox', { name: 'Select report type' }).click()
    assert.equal(await page.getByRole('option').count(), 7)
    await page.screenshot({ path: `screenshots/reports-review/controls-${light ? 'light' : 'dark'}.png` })
    await page.keyboard.press('Escape')
    await page.getByRole('button', { name: /date range/i }).click()
    assert.equal(await page.getByRole('dialog').count(), 1)
    await page.keyboard.press('Escape')
    console.log('PASS themed purple controls and glass menus', light ? 'light' : 'dark')
  }
  await page.evaluate(() => document.documentElement.classList.remove('theme-light'))
  for (const type of ['inactive','feedback','dailyCheckins','revenue','memberGrowth','memberOverview','recentActivity']) {
    await select.selectOption(type)
    await checkLayout(type)
    await page.getByRole('button', { name: /date range/i }).click()
    assert.equal(await page.getByLabel('Start date', { exact: true }).count(), 1)
    await page.keyboard.press('Escape')
    const before = await page.locator('tbody tr').first().innerText()
    await page.getByRole('button', { name: 'Next page', exact: true }).click()
    assert.notEqual(await page.locator('tbody tr').first().innerText(), before)
    assert.equal(await page.locator('tbody tr td').first().innerText(), '13')
    await page.getByRole('button', { name: 'Previous page', exact: true }).click()
    await page.getByRole('combobox', { name: 'Export format' }).click()
    await page.getByRole('option', { name: 'CSV', exact: true }).click()
    const downloadPromise = page.waitForEvent('download')
    await page.getByRole('button', { name: 'Export', exact: true }).click()
    const download = await downloadPromise
    const csv = readFileSync(await download.path(), 'utf8')
    assert.ok(csv.split('\n').length > 13, `${type}: export must contain more than the visible page`)
    assert.ok(download.suggestedFilename().startsWith(type === 'feedback' ? 'coach-feedback' : type))
    console.log('PASS pagination and complete CSV export', type)
  }
  await select.selectOption('feedback')
  await settle()
  await page.getByRole('button', { name: /date range/i }).click()
  await page.getByLabel('Start date', { exact: true }).fill('2026-01-01')
  await page.getByLabel('End date', { exact: true }).fill('2026-01-31')
  await page.getByRole('button', { name: 'Apply range' }).click()
  await settle()
  await page.getByRole('tab', { name: 'Inactive', exact: true }).click()
  await settle()
  assert.equal(await page.locator('tbody').innerText(), initial, 'Feedback dates must not change Inactive')
  console.log('PASS inactive survives report and date changes')
  await page.getByRole('tab', { name: 'Generation Reports' }).click()
  for (const type of ['dailyCheckins','revenue','memberGrowth','memberOverview','recentActivity','inactive']) {
    await select.selectOption(type)
    await page.getByRole('button', { name: /date range/i }).click()
    assert.equal(await page.getByLabel('Start date', { exact: true }).inputValue(), '2023-01-01', `${type}: feedback range leaked`)
    await page.getByLabel('Start date', { exact: true }).fill('2026-01-01')
    await page.getByLabel('End date', { exact: true }).fill('2026-01-31')
    await page.getByRole('button', { name: 'Apply range' }).click()
    await select.selectOption('feedback')
    await select.selectOption(type)
    await page.getByRole('button', { name: /date range/i }).click()
    assert.equal(await page.getByLabel('End date', { exact: true }).inputValue(), '2026-01-31', `${type}: range not preserved`)
    await page.keyboard.press('Escape')
  }
  await page.getByRole('tab', { name: 'Inactive', exact: true }).click()
  await settle()
  assert.equal(await page.locator('tbody').innerText(), initial)
  console.log('PASS independent date ranges for every report')
  for (const [width,height] of [[1920,1080],[1440,900],[1366,768]]) {
    await page.setViewportSize({ width,height })
    await checkLayout(`Inactive ${width}x${height}`)
    await page.getByRole('tab', { name: 'Generation Reports' }).click()
    await select.selectOption('feedback')
    await page.getByRole('button', { name: /date range/i }).click()
    await page.getByRole('button', { name: 'All time', exact: true }).click()
    await checkLayout(`Feedback ${width}x${height}`)
    await page.getByRole('tab', { name: 'Inactive', exact: true }).click()
  }
  assert.deepEqual(errors, [])
  mkdirSync('screenshots/reports-review', { recursive: true })
  await page.screenshot({ path: 'screenshots/reports-review/inactive.png' })
} finally { await browser.close() }
