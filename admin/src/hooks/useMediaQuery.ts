import { useEffect, useState } from 'react'

/**
 * True while the viewport matches a CSS media query, kept in sync as it changes.
 *
 * This is for the case a Tailwind `hidden lg:block` class CANNOT express: a
 * component that must not be MOUNTED at all, rather than merely be invisible.
 * Recharts' ResponsiveContainer measures its parent, so a chart inside a
 * `hidden` wrapper still mounts - at 0x0 - and logs "The width(0) and
 * height(0) of chart should be greater than 0" to the console on every resize.
 * The dashboard's own gate treats console noise as a defect, so the caller
 * asks this question and simply does not render the chart.
 *
 * The first answer is read synchronously during the initial state, so a wide
 * screen renders the wide layout on the very first paint with no flash and no
 * wasted render. `initial` is only the fallback for an environment without
 * `matchMedia`.
 *
 * The query string must be one the stylesheet already agrees with - the
 * dashboard donut passes the same 1024px that Tailwind's `lg` means - because
 * this hook and the CSS are two independent answers to the same question and
 * nothing enforces that they match.
 */
export function useMediaQuery(query: string, initial = false): boolean {
  const [matches, setMatches] = useState(() =>
    typeof window !== 'undefined' && typeof window.matchMedia === 'function'
      ? window.matchMedia(query).matches
      : initial,
  )

  useEffect(() => {
    if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return
    const mql = window.matchMedia(query)
    const onChange = () => setMatches(mql.matches)
    // The query can differ from the one read during init, so re-read on change.
    onChange()
    mql.addEventListener('change', onChange)
    return () => mql.removeEventListener('change', onChange)
  }, [query])

  return matches
}