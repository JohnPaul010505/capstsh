import { useCallback, useEffect, useLayoutEffect, useRef, useState, type RefObject } from 'react'

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
 *
 * NOTE: the admin list pages (members, trainers, memberships) do NOT use this.
 * They pin the page size at 15 and measure the row height instead - see
 * `useFitRowHeight` at the bottom of this file.
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

/**
 * Runs `measure` whenever the element can have changed size: on mount, on every
 * resize, and on a slow poll.
 *
 * The poll is not belt-and-braces. A container can mount at 0 (a hidden tab
 * panel, a collapsed drawer) and then never fire a resize, so a container
 * measured once at zero height stays at its fallback forever.
 */
function useMeasure<T extends HTMLElement>(ref: RefObject<T | null>, measure: () => void) {
  // useLayoutEffect, not useEffect: measuring after paint would show the
  // fallback value for a frame and then pop to the real one.
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
  }, [ref, measure])

  useEffect(() => {
    const id = window.setInterval(() => {
      if (ref.current && ref.current.clientHeight > 0) measure()
    }, 250)
    return () => window.clearInterval(id)
  }, [ref, measure])
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

  useMeasure(ref, measure)

  return [ref, rows] as const
}

export interface FitRowHeightOptions {
  /** The PINNED number of rows that have to fit - the list page size. */
  count: number
  /**
   * Height of non-row chrome inside the container, i.e. the sticky header row.
   *
   * 40 is `PeopleTable`'s header at its present padding (`py-2.5` around a
   * 12px/18px line box, plus the 1px rule), and it is the number that has to
   * be re-measured whenever that padding changes - not guessed. Overstating it
   * measures the rows short and leaves a gap under the last row; understating it
   * gives fifteen rows more room than the card has, and the clipped overflow
   * that follows is invisible because the container has no scrollbar to explain
   * it. It was 46 while the header was `py-3` around `text-sm`.
   */
  reserve?: number
  /**
   * Floor and ceiling for one row.
   *
   * The floor is not cosmetic: a table row cannot be shorter than the content
   * inside it, so a pinned height below that is ignored by the table layout and
   * the page grows a scrollbar anyway. 26px is roughly a 28px action button with
   * 1px of padding, which is the tallest thing any of these rows contain; below
   * that there is nothing left to give. The ceiling keeps rows from turning into
   * letterboxes on a 4K display.
   */
  min?: number
  max?: number
  /** Height used until the container has been measured (first paint). */
  fallback?: number
}

/**
 * The row height that makes exactly `count` rows fill the container, measured.
 *
 * This is `useFitRows` inverted, and the inversion is the whole point. The list
 * pages promise "15 rows, the rest on the next page", so the ROW COUNT is the
 * fixed contract and the row height is what gives. Measuring the count instead
 * (the previous setup) made the page size a function of the window: the footer
 * promised "1-25 of 987" above a body that only fitted 14 rows, and the
 * overflow appeared as a scrollbar with nothing to explain it.
 *
 * Attach the returned ref to the scroll container - the body, not the page.
 */
export function useFitRowHeight<T extends HTMLElement = HTMLDivElement>({
  count,
  reserve = 40,
  min = 26,
  max = 52,
  fallback = 44,
}: FitRowHeightOptions) {
  const ref = useRef<T>(null)
  const [rowHeight, setRowHeight] = useState(fallback)

  const measure = useCallback(() => {
    const el = ref.current
    if (!el) return
    const available = el.clientHeight - reserve
    const next = Math.max(min, Math.min(max, Math.floor(available / Math.max(1, count))))
    setRowHeight(prev => (prev === next ? prev : next))
  }, [count, reserve, min, max])

  useMeasure(ref, measure)

  return [ref, rowHeight] as const
}

export interface FitSquareOptions {
  /** The box's own horizontal padding, which the content cannot use. */
  pad?: number
  /** Vertical space taken by everything that is not the square (title, caption). */
  reserve?: number
  min?: number
  max?: number
  /** Side length used until the box has been measured (first paint). */
  fallback?: number
}

/**
 * The side length of the largest square that fits the element it is attached to.
 *
 * The QR page needs a code that fills its card instead of sitting in a fixed
 * 160px box in the middle of a 780px one. A pinned size cannot do that: the
 * page shell is a no-scroll `flex-1 min-h-0` column, so the card's real height
 * is a function of the window, and a number chosen for one viewport either
 * floats in a sea of card on a wide one or is clipped on a short one.
 *
 * Attach the returned ref to the CONTAINER the square must fit inside (the
 * card), not to the square. `clientWidth`/`clientHeight` include the padding, so
 * `pad` and `reserve` are what turn the raw box into the space actually free.
 *
 * The floor is not cosmetic either: a QR code below roughly 120px stops being
 * scannable off a phone, which is the whole point of the page.
 */
export function useFitSquare<T extends HTMLElement = HTMLDivElement>({
  pad = 48,
  reserve = 96,
  min = 120,
  // 500, not 160 and not "as big as possible". These two codes are printed on a
  // gym wall and scanned from a phone, so they should be as large as the card
  // allows - but the ceiling is what stops them reading as a mistake. Measured
  // across the supported viewports, the un-capped fit is 342px at 1024x768,
  // 513px at 1366x768 and 892px at 1920x1080, so the cap decides two of the
  // three: it was 620, which held 1920p at 74% of its card while 1024 came in
  // under it untouched. At 500 the 1080p card drops to 60% and 1366 moves 513
  // -> 500, a 13px trim that keeps the code clear of the card edge; 1024x768
  // is unaffected because its own fit never reaches the cap.
  max = 500,
  fallback = 240,
}: FitSquareOptions = {}) {
  const ref = useRef<T>(null)
  const [size, setSize] = useState(fallback)

  const measure = useCallback(() => {
    const el = ref.current
    if (!el) return
    const side = Math.min(el.clientWidth - pad, el.clientHeight - reserve)
    const next = Math.max(min, Math.min(max, Math.floor(side)))
    setSize(prev => (prev === next ? prev : next))
  }, [pad, reserve, min, max])

  useMeasure(ref, measure)

  return [ref, size] as const
}
