/**
 * Verifies the login page and the login -> dashboard handoff:
 *  1. Brand swap: man centred first, women.png + pink wash after ~3s.
 *  2. Layout: tagline removed, accent bar ends at the final "e" of
 *     "Welcome", password->button gap matches email->password spacing.
 *  3. Handoff: real sign-in, frame-by-frame capture — panels exit
 *     instantly, no dark gap, dashboard fades in.
 * Usage: node scripts/verify-login-swap.mjs [url]
 */
import { chromium } from 'playwright'
import { mkdirSync } from 'fs'

const url = process.argv[2] ?? 'http://localhost:5173/login'
const shots = 'screenshots/handoff'
mkdirSync(shots, { recursive: true })

async function run() {
  const browser = await chromium.launch()
  const page = await browser.newPage({ viewport: { width: 1920, height: 1000 } })
  await page.goto(url, { waitUntil: 'networkidle' })
  await page.waitForTimeout(800)

  const snapshot = () =>
    page.evaluate(() => {
      const state = el => {
        if (!el) return null
        const s = getComputedStyle(el)
        return { opacity: s.opacity, transform: s.transform, transition: s.transitionDuration }
      }
      const imgs = [...document.querySelectorAll('img')]
      const man = imgs.find(i => i.src.includes('man.png'))
      const woman = imgs.find(i => i.src.includes('women.png'))
      const h2 = document.querySelector('h2')
      const dash = h2?.previousElementSibling
      const form = document.querySelector('form')
      const kids = form ? [...form.children].map(k => k.getBoundingClientRect()) : []
      return {
        tagline: document.body.innerText.includes('Sign in to continue'),
        dashWidth: dash ? dash.getBoundingClientRect().width : null,
        man: state(man),
        woman: state(woman),
        gaps:
          kids.length >= 3
            ? {
                emailToPassword: kids[1].top - kids[0].bottom,
                passwordToButton: kids[2].top - kids[1].bottom,
              }
            : null,
      }
    })

  console.log('--- t=0 (expect man centred, woman off right) ---')
  console.log(JSON.stringify(await snapshot(), null, 2))

  await page.waitForTimeout(3400)
  console.log('--- t=+3.4s (expect woman centred, man off left) ---')
  console.log(JSON.stringify(await snapshot(), null, 2))

  await page.screenshot({ path: 'screenshots/login-woman-phase.png' })

  // ---- Handoff: real sign-in, frame-by-frame ----
  await page.locator('input[type=email]').fill('admin@fitness.com')
  await page.locator('input[type=password]').fill('Admin123!')
  await page.locator('button[type=submit]').click()

  for (let i = 0; i < 10; i++) {
    const state = await page.evaluate(() => {
      const overlay = document.querySelector('.login-exit-overlay')
      const panelL = document.querySelector('.panel-exit-left')
      const fade = document.querySelector('.app-fade-in')
      return {
        overlayOpacity: overlay ? getComputedStyle(overlay).opacity : null,
        panelExitLeft: !!panelL,
        dashboardOpacity: fade ? getComputedStyle(fade).opacity : null,
      }
    })
    console.log(`t+${i * 100}ms:`, JSON.stringify(state))
    await page.screenshot({ path: `${shots}/frame-${String(i).padStart(2, '0')}.png` })
    await page.waitForTimeout(100)
  }

  await page.waitForTimeout(800)
  console.log('final url:', page.url())
  await page.screenshot({ path: `${shots}/frame-final-dashboard.png` })
  console.log('filmstrip saved to', shots)
  await browser.close()
}

run().catch(e => {
  console.error(e)
  process.exit(1)
})
