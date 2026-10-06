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

/** 'Jan 15, 2026' — parsed as a local day. */
export function fmtDay(s: string): string {
  const d = parseDay(s)
  return `${MONTH_SHORT[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`
}

/**
 * The picker button label.
 *
 * A single-day range prints as one date rather than the date twice. The
 * attendance page opens on "today", which is a one-day range by definition,
 * and "Oct 5, 2026 - Oct 5, 2026" reads like a bug rather than like a day. A
 * multi-day range is unchanged, so the dashboard's labels are byte-identical.
 */
export function formatRangeLabel(r: Range): string {
  if (r.start === r.end) return fmtDay(r.start)
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

/**
 * The PREVIOUS calendar month, whole - not "the last 30 days".
 *
 * Attendance is the reason this exists: a gym reads its check-ins a month at a
 * time, so its chip list wants "Last month" where every other list page wants
 * "Last 7 days". Clamping the end to the last day of that month matters here,
 * because `lastNDays(30)` on the 1st would straddle two months and the header
 * would name a window the admin did not ask for.
 */
export function lastMonth(today: Date = new Date()): Range {
  return {
    start: toDay(new Date(today.getFullYear(), today.getMonth() - 1, 1)),
    end: toDay(new Date(today.getFullYear(), today.getMonth(), 0)),
  }
}

export function thisYear(today: Date = new Date()): Range {
  return { start: `${today.getFullYear()}-01-01`, end: toDay(today) }
}

/**
 * Inclusive first day of the demo dataset, as an Asia/Manila civil date.
 *
 * The seed declares the same literal in `scripts/seed/lib/common.mjs`. The app
 * cannot import that module - it calls `dotenv.config()` and constructs a
 * service-role Supabase client, neither of which may enter a browser bundle - so
 * the value is declared on both sides and `scripts/verify-dataset-spread.mjs`
 * reads both files and fails the run if they drift.
 *
 * This bounds the `All time` preset and the picker's minimum, so no range can be
 * requested that the data does not cover.
 */
export const DATA_START = '2023-01-01'

/** The whole dataset, `DATA_START` through today. */
export function allTime(today: Date = new Date()): Range {
  return { start: DATA_START, end: toDay(today) }
}

/**
 * True when the range IS the `All time` preset - `DATA_START` through today.
 *
 * The list pages open on All time, and on that range they send NO date filter
 * to PostgREST at all rather than sending `gte(col,'2023-01-01').lte(col,today)`.
 * Two reasons, and the second is the one that bites:
 *
 *   1. The landing render is then byte-identical to the page before it had a
 *      date control at all.
 *   2. `created_at` is a `timestamptz`. A bare `'2023-01-01'` is cast by
 *      Postgres in the session timezone (UTC), so the bound lands 8 hours
 *      BEFORE local midnight on the dataset's first day - and the member who
 *      joined that morning silently drops out of the list, taking the release
 *      gate's "total is 987" assertion with it.
 */
export function isAllTime(r: Range, today: Date = new Date()): boolean {
  return r.start === DATA_START && r.end === toDay(today)
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
  { id: 'all', label: 'All time', apply: allTime },
]

/** Look a preset up by id so the chip groups below cannot drift from the list. */
const preset = (id: string) => {
  const found = RANGE_PRESETS.find(p => p.id === id)
  if (!found) throw new Error(`no RANGE_PRESETS entry with id "${id}"`)
  return found
}

/**
 * The chips the LIST pages show: Today, Last 7 days, This month, All time.
 *
 * `DateRangePicker` falls back to the full seven-preset list when it is given
 * none, which is what the dashboard wants - it has charts to draw, so the longer
 * windows are the point. A table of rows does not: it shows the newest 50, and
 * a "Last 90 days" chip on top of that mostly narrows to nothing. These five
 * pages want the four windows that actually return rows.
 */
export const LIST_PRESETS: RangePreset[] =
  ['today', '7d', 'month', 'all'].map(preset)

/**
 * The chips ATTENDANCE shows: Last month, This month, Today, All time.
 *
 * "Last month" is not in `RANGE_PRESETS` and deliberately was not added there:
 * a rolling 30-day window is a poor default read on a monthly sheet, and adding
 * the chip to the dashboard would have changed a picker the dashboard's own
 * release gate exercises. It is declared here instead, and the four other chips
 * are still looked up by id so the two lists cannot disagree about what
 * "All time" means.
 */
export const MONTH_PRESETS: RangePreset[] = [
  { id: 'lastmonth', label: 'Last month', apply: lastMonth },
  preset('month'),
  preset('today'),
  preset('all'),
]

/**
 * The equal-length window immediately before `r` — the honest comparison
 * basis for the "vs previous N days" KPI lines.
 */
export function prevWindow(r: Range): Range {
  const days = daysBetween(r.start, r.end)
  const end = new Date(parseDay(r.start).getTime() - 86_400_000)
  const start = new Date(end.getTime() - (days - 1) * 86_400_000)
  return { start: toDay(start), end: toDay(end) }
}

/** A bucket-count budget, NOT a day budget. */
const MAX_BUCKETS = 120

/**
 * Which grains can honestly be DRAWN for this span.
 *
 * All time is 1,369 days over the demo roster, so Daily is 1,369 buckets and
 * Weekly is 196: at ~1,700px of chart width that is roughly one pixel per bar
 * and a y-axis of 0..1, which is a solid block rather than a trend. The range
 * is still answered, just at Monthly, where a bucket is a calendar month.
 *
 * This is a cap, not a redefinition of the default: `autoGrain` still opens
 * 30 days on Daily and 90 days on Weekly, so nothing about the short ranges
 * moves. The list is ordered finest-first, which is what makes it the input to
 * `autoGrain` rather than a second, competing rule.
 */
export function grainsForRange(r: Range): Grain[] {
  const n = daysBetween(r.start, r.end)
  const out: Grain[] = []
  if (n <= MAX_BUCKETS) out.push('daily')
  if (Math.ceil(n / 7) <= MAX_BUCKETS) out.push('weekly')
  out.push('monthly')
  return out
}

/**
 * Auto-pick a granularity that stays readable for the span.
 *
 * The thresholds are the long-standing 45/200-day ones, but the result is
 * intersected with `grainsForRange` so the automatic grain is ALWAYS one the
 * span can render. A grain picked by hand survived a range change in
 * DashboardPage - choose Daily on 30 days, switch to All time, and you got the
 * 1,369-bucket wall - so the guard has to live here, not only in the caller.
 */
export function autoGrain(r: Range): Grain {
  const n = daysBetween(r.start, r.end)
  const allowed = grainsForRange(r)
  if (n <= 45 && allowed.includes('daily')) return 'daily'
  if (n <= 200 && allowed.includes('weekly')) return 'weekly'
  return 'monthly'
}

/** True when the range touches more than one calendar year. */
function spansYears(r: Range): boolean {
  return parseDay(r.start).getFullYear() !== parseDay(r.end).getFullYear()
}

/** "'23" — the two-digit year suffix for axis labels that cross a year boundary. */
const yearTag = (d: Date) => `'${String(d.getFullYear()).slice(2)}`

/**
 * Split a range into chart buckets.
 * daily   → one bucket per day (day-of-month label when the range sits in a
 *           single month, else 'Jan 15' style so month-crossing stays clear).
 * weekly  → calendar weeks Mon..Sun clipped to the range.
 * monthly → calendar months touched by the range.
 *
 * Every grain that CAN span a year boundary carries the year in its short
 * label ("Jan '23"), because on All time the un-suffixed labels repeat: two
 * ticks reading "Jan" were indistinguishable, and a reader could not tell the
 * first January from the last. Single-year ranges keep the bare short labels,
 * so the common short-range charts read exactly as they always have.
 */
export function bucketize(range: Range, grain: Grain): Bucket[] {
  const multiYear = spansYears(range)

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
        label: multiYear
          ? `${MONTH_SHORT[cursor.getMonth()]} ${yearTag(cursor)}`
          : MONTH_SHORT[cursor.getMonth()],
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
        label: multiYear
          ? `${MONTH_SHORT[d.getMonth()]} ${d.getDate()} ${yearTag(d)}`
          : `${MONTH_SHORT[d.getMonth()]} ${d.getDate()}`,
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
      label: sameMonth
        ? String(d.getDate())
        // A day number alone is enough inside one month; past a year boundary
        // the month is needed to place it, and the year to place THAT.
        : multiYear
          ? `${MONTH_SHORT[d.getMonth()]} ${d.getDate()} ${yearTag(d)}`
          : `${MONTH_SHORT[d.getMonth()]} ${d.getDate()}`,
      full: fmtDay(day),
      start: day,
      end: day,
    }
  })
}

