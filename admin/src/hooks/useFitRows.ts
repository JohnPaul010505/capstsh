import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'

/**
 * How many table rows fit the available height, measured rather than guessed.
 *
 * The no-scroll list pages need a row count that reacts to the window: a fixed
 * page size either leaves a gap on a tall screen or overflows on a short one,
 * and the overflow is invisible because the container clips. This measures the
 * element it is attached to and divides.
 *
 * Attach the returned ref to the scroll container, NOT the page. The container
 * is the thing whose height is the budget.
 */
export interface FitRowsOptions {
  /** Height consumed by non-row chrome inside the container (header row, padding). */
  reserve?: number
  /** Measured height of one row; defaults to the 44px the list tables use. */
  rowHeight?: number
  min?: number
  max?: number
  /** Passed to the caller so it can show at least a full page on first paint. */
  fallback?: number
}

export function useFitRows<T extends HTMLElement = HTMLDivElement>({
  reserve = 44,
  rowHeight = 44,
  min = 5,
  max = 200,
  fallback = 20,
}: FitRowsOptions = {}) {
  const ref = useRef<T>(null)
  const [rows, setRows] = useState(fallback)

  const measure = useCallback(() => {
    const el = ref.current
    if (!el) return
    const available = el.clientHeight - reserve
    const next = Math.max(min, Math.min(max, Math.floor(available / rowHeight)))
    // Only write state on a real change: a resize observer that fires on every
    // layout pass would otherwise re-render the table in a loop.
    setRows(prev => (prev === next ? prev : next))
  }, [reserve, rowHeight, min, max])

  // useLayoutEffect, not useEffect: measuring after paint would show the
  // fallback row count for a frame and then pop to the real one.
  useLayoutEffect(() => {
    measure()
    const el = ref.current
    if (!el || typeof ResizeObserver === 'undefined') {
      window.addEventListener('resize', measure)
      return () => window.removeEventListener('resize', measure)
    }
    const ro = new ResizeObserver(measure)
    ro.observe(el)
    return () => ro.disconnect()
  }, [measure])

  // The container can mount at 0 (a hidden tab panel, a collapsed drawer) and
  // never fire a resize, so re-measure once the element actually has a height.
  useEffect(() => {
    const id = window.setInterval(() => {
      if (ref.current && ref.current.clientHeight > 0) measure()
    }, 250)
    return () => window.clearInterval(id)
  }, [measure])

  return [ref, rows] as const
}
