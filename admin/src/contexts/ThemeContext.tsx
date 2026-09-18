import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react'

type Theme = 'dark' | 'light'

interface ThemeContextValue {
  theme: Theme
  toggleTheme: () => void
  /** Jump straight to a theme (used by Login to pin the dark neon look). */
  setTheme: (theme: Theme) => void
}

const ThemeContext = createContext<ThemeContextValue>({
  theme: 'dark',
  toggleTheme: () => {},
  setTheme: () => {},
})

/**
 * In-place theme switch, in ms. While a switch runs, <html> carries the
 * .theme-transitioning class (see the html.theme-transitioning rule in
 * index.css) so every CSS-variable-driven colour crossfades where it stands.
 * No opaque veil, no full-screen flash, and page state is never touched.
 */
const TRANSITION_MS = 650

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setThemeState] = useState<Theme>(() => {
    if (typeof window === 'undefined') return 'dark'
    const stored = window.localStorage.getItem('admin-theme')
    return stored === 'light' ? 'light' : 'dark'
  })
  const transitionTimer = useRef<number | undefined>(undefined)

  useEffect(() => {
    const root = document.documentElement
    root.classList.remove('theme-dark', 'theme-light')
    root.classList.add(`theme-${theme}`)
    root.style.colorScheme = theme
    window.localStorage.setItem('admin-theme', theme)

    // Keep the browser chrome colour in step with the page background —
    // --veil holds the page colour for the theme that is now active.
    const veil = getComputedStyle(root).getPropertyValue('--veil').trim()
    const meta = document.querySelector('meta[name="theme-color"]')
    if (meta && veil) meta.setAttribute('content', veil)
  }, [theme])

  // Drop the transition class if the provider unmounts mid-switch.
  useEffect(() => () => window.clearTimeout(transitionTimer.current), [])

  const toggleTheme = useCallback(() => {
    // Reduced motion: swap instantly, no crossfade.
    if (typeof window !== 'undefined'
      && window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      setThemeState(t => (t === 'dark' ? 'light' : 'dark'))
      return
    }

    // Enable colour transitions only for the duration of the switch, so
    // hover effects and other transitions are unaffected the rest of the
    // time. Rapid re-toggles just extend the window.
    const root = document.documentElement
    root.classList.add('theme-transitioning')
    window.clearTimeout(transitionTimer.current)
    transitionTimer.current = window.setTimeout(
      () => root.classList.remove('theme-transitioning'), TRANSITION_MS)

    setThemeState(t => (t === 'dark' ? 'light' : 'dark'))
  }, [])

  const setTheme = useCallback((next: Theme) => setThemeState(next), [])

  return (
    <ThemeContext.Provider value={{ theme, toggleTheme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  )
}

export function useTheme() {
  const ctx = useContext(ThemeContext)
  if (!ctx) throw new Error('useTheme must be used within ThemeProvider')
  return ctx
}
