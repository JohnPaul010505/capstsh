/**
 * Dashboard date-range helpers.
 *
 * All comparisons against `date` columns use plain 'YYYY-MM-DD' strings
 * built from LOCAL calendar parts — never `toISOString().slice(0, 10)`,
 * which shifts every date back one day in PH (UTC+8). `timestamptz`
 * columns use real local-midnight ISO boundaries instead.
 */

export interface Range {
  /** Inclusive start, 'YYYY-MM-DD' (local day). */
  start: string
  /** Inclusive end, 'YYYY-MM-DD' (local day). */
  end: string
}

export type Grain = 'daily' | 'weekly' | 'monthly'

export interface Bucket {
  /** Stable key for chart dataKeys / React keys. */
  key: string
  /** Short axis label (e.g. '15', 'Jan 15', 'Jan'). */
  label: string
  /** Full label for tooltips (e.g. 'Jan 15, 2026 - Jan 21, 2026'). */
  full: string
  /** Inclusive local-day bounds the bucket covers. */
  start: string
  end: string
}

const pad = (n: number) => String(n).padStart(2, '0')

export const MONTH_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

/** Local calendar day as 'YYYY-MM-DD'. */
export function toDay(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

/** Parse a 'YYYY-MM-DD' string as LOCAL midnight (not UTC midnight). */
export function parseDay(s: string): Date {
  return new Date(`${s}T00:00:00`)
}

/** Inclusive-lower ISO bound for `timestamptz` columns. */
export function localStartIso(s: string): string {
  return parseDay(s).toISOString()
}

/** Inclusive-upper ISO bound for `timestamptz` columns (end of local day). */
export function localEndIso(s: string): string {
  return new Date(parseDay(s).getTime() + 86_400_000 - 1).toISOString()
}

/** Inclusive day count: daysBetween('2026-01-15', '2026-03-15') === 60. */
export function daysBetween(a: string, b: string): number {
  return Math.round((parseDay(b).getTime() - parseDay(a).getTime()) / 86_400_000) + 1
}

/** Every local day in [a, b], inclusive, ascending. */
export function eachDay(a: string, b: string): string[] {
  const out: string[] = []
  const d = parseDay(a)
  const end = parseDay(b)
  while (d.getTime() <= end.getTime()) {
    out.push(toDay(d))
    d.setDate(d.getDate() + 1)
  }
  return out
}

/** Put a range in start<=end order (ISO strings compare lexicographically). */
export function normalizeRange(a: string, b: string): Range {
  return a <= b ? { start: a, end: b } : { start: b, end: a }
}

function fmtDay(s: string): string {
  const d = parseDay(s)
  return `${MONTH_SHORT[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`
}

/** 'Jan 15, 2026 - Mar 15, 2026' — the picker button label. */
export function formatRangeLabel(r: Range): string {
  return `${fmtDay(r.start)} - ${fmtDay(r.end)}`
}

export function todayRange(today: Date = new Date()): Range {
  const t = toDay(today)
  return { start: t, end: t }
}

export function lastNDays(n: number, today: Date = new Date()): Range {
  return { start: toDay(new Date(today.getTime() - (n - 1) * 86_400_000)), end: toDay(today) }
}

export function thisMonth(today: Date = new Date()): Range {
  const first = `${today.getFullYear()}-${pad(today.getMonth() + 1)}-01`
  return { start: first, end: toDay(new Date(today.getFullYear(), today.getMonth() + 1, 0)) }
}

export function thisYear(today: Date = new Date()): Range {
  return { start: `${today.getFullYear()}-01-01`, end: toDay(today) }
}

export interface RangePreset {
  id: string
  label: string
  apply: (today: Date) => Range
}

export const RANGE_PRESETS: RangePreset[] = [
  { id: 'today', label: 'Today', apply: t => todayRange(t) },
  { id: '7d', label: 'Last 7 days', apply: t => lastNDays(7, t) },
  { id: 'month', label: 'This month', apply: t => thisMonth(t) },
  { id: '30d', label: 'Last 30 days', apply: t => lastNDays(30, t) },
  { id: '90d', label: 'Last 90 days', apply: t => lastNDays(90, t) },
  { id: 'year', label: 'This year', apply: t => thisYear(t) },
  { id: 'all', label: 'All time', apply: t => ({ start: '2020-01-01', end: toDay(t) }) },
]

/** Auto-pick a granularity that stays readable for the span. */
export function autoGrain(r: Range): Grain {
  const n = daysBetween(r.start, r.end)
  if (n <= 45) return 'daily'
  if (n <= 200) return 'weekly'
  return 'monthly'
}

/**
 * Split a range into chart buckets.
 * daily   → one bucket per day (day-of-month label when the range sits in a
 *           single month, else 'Jan 15' style so month-crossing stays clear).
 * weekly  → calendar weeks Mon..Sun clipped to the range.
 * monthly → calendar months touched by the range.
 */
export function bucketize(range: Range, grain: Grain): Bucket[] {
  if (grain === 'monthly') {
    const out: Bucket[] = []
    const cursor = parseDay(range.start)
    cursor.setDate(1)
    const end = parseDay(range.end)
    while (cursor.getTime() <= end.getTime()) {
      const key = `${cursor.getFullYear()}-${pad(cursor.getMonth() + 1)}`
      const monthStart = toDay(cursor)
      const lastOfMonth = toDay(new Date(cursor.getFullYear(), cursor.getMonth() + 1, 0))
      const bucketEnd = lastOfMonth > range.end ? range.end : lastOfMonth
      const bucketStart = monthStart < range.start ? range.start : monthStart
      out.push({
        key,
        label: MONTH_SHORT[cursor.getMonth()],
        full: `${MONTH_SHORT[cursor.getMonth()]} ${cursor.getFullYear()}`,
        start: bucketStart,
        end: bucketEnd,
      })
      cursor.setMonth(cursor.getMonth() + 1)
    }
    return out
  }

  if (grain === 'weekly') {
    const out: Bucket[] = []
    // Monday of the week containing range.start (getDay: Sun=0).
    const start = parseDay(range.start)
    start.setDate(start.getDate() - ((start.getDay() + 6) % 7))
    const end = parseDay(range.end)
    const cursor = start
    while (cursor.getTime() <= end.getTime()) {
      const key = toDay(cursor)
      const sunday = toDay(new Date(cursor.getTime() + 6 * 86_400_000))
      const bucketStart = key < range.start ? range.start : key
      const bucketEnd = sunday > range.end ? range.end : sunday
      const d = parseDay(bucketStart)
      out.push({
        key,
        label: `${MONTH_SHORT[d.getMonth()]} ${d.getDate()}`,
        full: `${fmtDay(bucketStart)} – ${fmtDay(bucketEnd)}`,
        start: bucketStart,
        end: bucketEnd,
      })
      cursor.setDate(cursor.getDate() + 7)
    }
    return out
  }

  // daily
  const days = eachDay(range.start, range.end)
  const sameMonth = range.start.slice(0, 7) === range.end.slice(0, 7)
  return days.map(day => {
    const d = parseDay(day)
    return {
      key: day,
      label: sameMonth ? String(d.getDate()) : `${MONTH_SHORT[d.getMonth()]} ${d.getDate()}`,
      full: fmtDay(day),
      start: day,
      end: day,
    }
  })
}

