/**
 * Verifies the login <-> dashboard handoff end to end:
 *
 *   1. Login page has exactly ONE password-reveal control (the custom
 *      lucide Eye/EyeOff button). The native Edge/IE ::-ms-reveal glyph is
 *      suppressed by a stylesheet rule, asserted by scanning document.styleSheets.
 *   2. Sign-in: the overlay holds while the dashboard fades in behind it, then
 *      the login wrapper is dropped -- never a frame where BOTH screens are
 *      invisible (the old black-flash regression).
 *   3. Sign-out: the sidebar "Sign Out" -> ConfirmDialog "Yes" path. The
 *      dashboard fades out while the login panels slide back in from the edges
 *      (.panel-enter-*), again with no invisible frame, and the form is
 *      editable straight afterwards.
 *
 * Usage:  node scripts/verify-auth-animations.mjs [url]
 * Needs:  API on :3001, Vite on :5173.
 * Output: screenshots/handoff-reverse/ + exit code 1 when a check fails.
 */
import { chromium } from 'playwright'
import { mkdirSync, readFileSync } from 'fs'

const BASE = (process.argv[2] ?? 'http://localhost:5173').replace(/\/$/, '')
const SHOTS = 'screenshots/handoff-reverse'
mkdirSync(SHOTS, { recursive: true })

const EMAIL = 'admin@fitness.com'
const PASSWORD = 'Admin123!'

/** An element "shows the app" above this fractional opacity. */
const VISIBLE_OPACITY = 0.05

const failures = []
function check(label, ok, detail) {
  console.log(`  [${ok ? 'PASS' : 'FAIL'}] ${label}${detail ? ' -- ' + detail : ''}`)
  if (!ok) failures.push(label)
}

// Removes CSS block comments so brace/rule matching sees only real CSS.
function stripComments(css) {
  return css.replace(/\/\*[\s\S]*?\*\//g, '')
}

/**
 * True when `needle` sits inside an `@layer { ... }` block of `css`.
 * Tailwind processes everything inside @layer, so a rule that must survive
 * verbatim has to live outside it.
 */
function insideAtLayer(css, needle) {
  const idx = css.indexOf(needle)
  if (idx < 0) return false
  const stack = []
  for (let i = 0; i < idx; i++) {
    if (css[i] === '{') {
      stack.push(/@layer[^{;]*$/.test(css.slice(Math.max(0, i - 60), i)) ? 'layer' : 'block')
    } else if (css[i] === '}') {
      stack.pop()
    }
  }
  return stack.includes('layer')
}

/**
 * Starts a requestAnimationFrame sampler inside the page.
 *
 * Sampling has to happen in-page: driving the filmstrip from Node with
 * page.evaluate + page.screenshot leaves 300ms+ gaps (screenshotting a blurred
 * 1920x1040 backdrop is expensive), so a 750ms handoff can start and finish
 * between two samples and the assertions miss it entirely. rAF records every
 * real frame instead.
 *
 * The two wrappers are located structurally (root child 0 = dashboard,
 * child 1 = login) so the idle state -- which carries no animation class -- is
 * measured too. Without that, the blank-frame check cannot tell idle-on-login
 * apart from neither-screen-visible.
 */
async function startSampling(page) {
  await page.evaluate(() => {
    window.__fr = []
    const read = () => {
      const style = (el) => {
        if (!el) return null
        const s = getComputedStyle(el)
        const r = el.getBoundingClientRect()
        return {
          cls: String(el.className),
          opacity: Number(parseFloat(s.opacity).toFixed(3)),
          transform: s.transform === 'none' ? 'none' : s.transform,
          display: s.display,
          visible: r.width > 0 && r.height > 0,
        }
      }
      const q = (sel) => style(document.querySelector(sel))
      // Live Web Animations info: distinguishes "the fade is actually running"
      // from "a class was applied but no frame ever rendered".
      const anim = (el) => {
        if (!el) return null
        const a = el.getAnimations()[0]
        if (!a || !a.effect) return null
        const timing = a.effect.getComputedTiming()
        return {
          name: a.animationName,
          playState: a.playState,
          progress: timing.progress === null ? null : Number(timing.progress.toFixed(3)),
        }
      }
      const root = document.getElementById('root')
      return {
        t: Math.round(performance.now()),
        path: location.pathname,
        dashWrap: style(root ? root.children[0] : null),
        dashAnim: anim(root ? root.children[0] : null),
        loginWrap: style(root ? root.children[1] : null),
        enterBackdrop: q('.login-enter-overlay .admin-base-bg'),
        exitL: q('.panel-exit-left'),
        exitR: q('.panel-exit-right'),
        enterL: q('.panel-enter-left'),
        enterR: q('.panel-enter-right'),
      }
    }
    let raf = 0
    const tick = () => {
      window.__fr.push(read())
      raf = requestAnimationFrame(tick)
    }
    window.__frStop = () => cancelAnimationFrame(raf)
    tick()
  })
}

/** Stops the sampler and returns the frames, rebased so the first is t=0. */
async function stopSampling(page) {
  const frames = await page.evaluate(() => {
    if (window.__frStop) window.__frStop()
    const out = window.__fr.slice()
    window.__fr = []
    return out
  })
  if (!frames.length) return frames
  const t0 = frames[0].t
  return frames.map((f) => ({ ...f, t: f.t - t0 }))
}

/** Prints one line per class change, which is what actually matters. */
function logStrip(label, frames) {
  console.log(`  ${label}: ${frames.length} frames sampled`)
  let prev = null
  for (const f of frames) {
    const sig = `${f.dashWrap ? f.dashWrap.cls : '-'}|${f.loginWrap ? f.loginWrap.cls : '-'}`
    if (sig === prev) continue
    prev = sig
    const d = f.dashWrap
    const l = f.loginWrap
    console.log(
      `   t+${String(f.t).padStart(5)}ms` +
        `  dash="${d ? d.cls || '(idle)' : '-'}" op=${d ? d.opacity : '-'}` +
        `  login="${l ? l.cls || '(idle)' : '-'}" op=${l ? l.opacity : '-'}` +
        `  backdrop=${f.enterBackdrop ? f.enterBackdrop.opacity : 'n/a'}`,
    )
  }
}

/**
 * First frame in which NEITHER screen is showing. Uses the structural wrappers,
 * so it works for the idle state and for both handoff directions.
 */
function firstBlankFrame(frames) {
  return frames.find(
    (f) =>
      !(
        (f.dashWrap && f.dashWrap.visible && f.dashWrap.opacity > VISIBLE_OPACITY) ||
        (f.loginWrap && f.loginWrap.visible && f.loginWrap.opacity > VISIBLE_OPACITY)
      ),
  )
}

/** Lowest wrapper opacity across the frames carrying `cls`. */
function minOpacity(frames, key, cls) {
  const vals = frames.filter((f) => f[key] && f[key].cls.includes(cls)).map((f) => f[key].opacity)
  return vals.length ? Math.min(...vals) : null
}

async function run() {
  const browser = await chromium.launch()
  const page = await browser.newPage({ viewport: { width: 1920, height: 1040 } })
  const errors = []
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message))
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push('console: ' + m.text())
  })

  console.log('=== 1) Login page: single password-reveal control ===')
  await page.goto(BASE + '/login', { waitUntil: 'networkidle' })
  await page.waitForTimeout(1400)

  const toggleIdle = await page.locator('form button[aria-label*="password" i]').count()
  await page.screenshot({ path: SHOTS + '/1-toggle.png' })
  console.log('  password toggle buttons (before typing):', toggleIdle, '(expect 1)')

  await page.locator('input[type="password"]').fill('SuperSecret1!')
  await page.waitForTimeout(300)
  const toggleTyped = await page.locator('form button[aria-label*="password" i]').count()
  console.log('  password toggle buttons (after typing): ', toggleTyped, '(expect 1)')
  await page.screenshot({ path: SHOTS + '/1-after-type.png' })

  // Chromium does not implement ::-ms-reveal, so it DROPS the whole rule at
  // parse time and a CSSOM scan always comes back empty -- even though the rule
  // is correct and active in Edge, which does implement the pseudo-element.
  // Assert against the stylesheet source, the artefact both browsers consume,
  // instead of the Chromium CSSOM.
  const css = stripComments(readFileSync('src/index.css', 'utf8'))
  const revealBody = (css.match(/input\[type='password'\]::-ms-reveal[\s\S]*?\{([^}]*)\}/) ?? [])[1]
  const revealInLayer = insideAtLayer(css, "input[type='password']::-ms-reveal")
  console.log(
    '  ::-ms-reveal rule body:',
    revealBody ? JSON.stringify(revealBody.trim()) : 'MISSING',
    '| inside @layer:',
    revealInLayer,
  )

  check('exactly one password toggle when idle', toggleIdle === 1, `count=${toggleIdle}`)
  check('exactly one password toggle after typing', toggleTyped === 1, `count=${toggleTyped}`)
  check(
    '::-ms-reveal suppressed in stylesheet (display:none, outside @layer)',
    !!revealBody && /display:\s*none/.test(revealBody) && !revealInLayer,
    revealBody ? `body="${revealBody.trim()}" inLayer=${revealInLayer}` : 'rule not found',
  )

  console.log('')
  console.log('=== 2) Sign-in handoff filmstrip ===')
  await page.locator('input[type="email"]').fill(EMAIL)
  await page.locator('input[type="password"]').fill(PASSWORD)
  await startSampling(page)
  await page.locator('button[type="submit"]').click()
  await page.waitForTimeout(2500)
  const signin = await stopSampling(page)
  logStrip('sign-in', signin)

  console.log('  post-sign-in URL:', page.url())
  await page.screenshot({ path: SHOTS + '/2-final.png' })

  check('sign-in lands on the dashboard', page.url().includes('/dashboard'), page.url())
  const blankIn = firstBlankFrame(signin)
  check(
    'no blank frame during sign-in',
    !blankIn,
    blankIn ? `neither screen visible at t+${blankIn.t}ms` : 'every frame had a visible screen',
  )
  const exitOverlayFrames = signin.filter(
    (f) => f.loginWrap && f.loginWrap.cls.includes('login-exit-overlay'),
  )
  check(
    'login exit overlay engages during sign-in',
    exitOverlayFrames.length > 0,
    `frames=${exitOverlayFrames.length}`,
  )
  check(
    'login panels split outward during sign-in (panel-exit-*)',
    !!signin.find((f) => f.exitL) && !!signin.find((f) => f.exitR),
    `exitL=${!!signin.find((f) => f.exitL)} exitR=${!!signin.find((f) => f.exitR)}`,
  )
  const fadeInFrames = signin.filter((f) => f.dashWrap && f.dashWrap.cls.includes('app-fade-in'))
  const fadeInMids = fadeInFrames.filter((f) => f.dashWrap.opacity > 0 && f.dashWrap.opacity < 1).length
  console.log(
    `  fade-in frames=${fadeInFrames.length} intermediate-opacity=${fadeInMids}` +
      ` minOp=${fadeInFrames.length ? Math.min(...fadeInFrames.map((f) => f.dashWrap.opacity)) : 'n/a'}`,
  )
  check(
    'dashboard genuinely fades in (no snap)',
    fadeInMids > 0,
    `intermediate=${fadeInMids} min=${minOpacity(signin, 'dashWrap', 'app-fade-in')}`,
  )
  const lastIn = signin[signin.length - 1]
  check(
    'login wrapper is hidden once the handoff finishes',
    !!lastIn.loginWrap && lastIn.loginWrap.display === 'none',
    lastIn.loginWrap ? lastIn.loginWrap.cls : 'no wrapper',
  )
  const firstDash = signin.find(
    (f) => f.dashWrap && f.dashWrap.cls.includes('app-fade-in') && f.dashWrap.opacity > VISIBLE_OPACITY,
  )
  console.log('  dashboard first visible at t+' + (firstDash ? firstDash.t : 'never') + 'ms')
  check('dashboard appears during the sign-in handoff', !!firstDash)

  console.log('')
  console.log('=== 3) Sign-out handoff filmstrip ===')
  await page.locator('aside button:has-text("Sign Out")').first().click()
  const confirmBtn = page.locator('button:has-text("Yes")').first()
  await confirmBtn.waitFor({ state: 'visible', timeout: 5000 })
  await page.screenshot({ path: SHOTS + '/3-confirm.png' })
  await startSampling(page)
  await confirmBtn.click()
  await page.waitForTimeout(2500)
  const signout = await stopSampling(page)
  logStrip('sign-out', signout)

  console.log('  post-sign-out URL:', page.url())
  await page.screenshot({ path: SHOTS + '/3-final.png' })

  const blankOut = firstBlankFrame(signout)
  check(
    'no blank frame during sign-out',
    !blankOut,
    blankOut ? `neither screen visible at t+${blankOut.t}ms` : 'every frame had a visible screen',
  )
  const enterOverlayFrames = signout.filter(
    (f) => f.loginWrap && f.loginWrap.cls.includes('login-enter-overlay'),
  )
  check(
    'login enter overlay engages during sign-out',
    enterOverlayFrames.length > 0,
    `frames=${enterOverlayFrames.length}`,
  )
  check('left panel slides back in (panel-enter-left)', !!signout.find((f) => f.enterL))
  check('right panel slides back in (panel-enter-right)', !!signout.find((f) => f.enterR))
  const fadeOutFrames = signout.filter((f) => f.dashWrap && f.dashWrap.cls.includes('app-fade-out'))
  const fadeOutRan = signout.some(
    (f) => f.dashAnim && f.dashAnim.name === 'appFadeOut' && (f.dashAnim.progress ?? 0) > 0,
  )
  const fadeOutMids = fadeOutFrames.filter(
    (f) => f.dashWrap.opacity > 0 && f.dashWrap.opacity < 1,
  ).length
  console.log(
    `  fade-out frames=${fadeOutFrames.length} intermediate-opacity=${fadeOutMids} fadeOutRan=${fadeOutRan}` +
      ` minOp=${fadeOutFrames.length ? Math.min(...fadeOutFrames.map((f) => f.dashWrap.opacity)) : 'n/a'}`,
  )
  check('dashboard gets app-fade-out during sign-out', fadeOutFrames.length > 0)
  // Deliberately not asserting "reaches opacity 0". Headless Chromium rasters the
  // blurred backdrop layers in software, so the first frame after the login tree
  // mounts can land 300ms+ into a 550ms animation; the handoff timer then drops
  // the class first. Asserting that the animation ran (progress > 0) and that at
  // least one frame caught a partial opacity proves it is a fade, not a snap.
  check(
    'dashboard genuinely fades out (no snap)',
    fadeOutRan && fadeOutMids > 0,
    `progress>0=${fadeOutRan} intermediate=${fadeOutMids}`,
  )
  const firstUnfaded = signout.find(
    (f) => f.enterBackdrop && f.enterBackdrop.opacity > VISIBLE_OPACITY,
  )
  console.log(
    '  login backdrop first visible at t+' + (firstUnfaded ? firstUnfaded.t : 'never') + 'ms',
  )
  // The login overlay's AppBackground is static (not animated) so the shared
  // backdrop never doubles up in the compositor. It must be fully opaque the
  // moment the overlay appears, otherwise the dashboard's fading backdrop would
  // show through and the screen would darken mid-transition.
  check('login backdrop present and opaque during sign-out', !!firstUnfaded)

  const lastOut = signout[signout.length - 1]
  check(
    'dashboard wrapper is hidden once the handoff finishes',
    !!lastOut.dashWrap && lastOut.dashWrap.display === 'none',
    lastOut.dashWrap ? lastOut.dashWrap.cls : 'no wrapper',
  )

  // The reformed login form must be usable straight away.
  const formUsable = await page.locator('input[type="email"]').first().isEditable()
  check('reformed login form is editable', formUsable)

  await browser.close()

  const consoleErrors = errors.filter((e) => !/favicon|404 \(Not Found\)/i.test(e))
  check('no console/page errors', consoleErrors.length === 0, consoleErrors.join(' | ') || 'none')

  console.log('')
  console.log('=== SUMMARY ===')
  console.log(`screenshots: ${SHOTS}`)
  if (failures.length) {
    console.log(`RESULT: FAIL (${failures.length}) -> ${failures.join('; ')}`)
    process.exitCode = 1
  } else {
    console.log('RESULT: PASS (all checks)')
  }
}

run().catch((e) => {
  console.error(e)
  process.exit(1)
})
