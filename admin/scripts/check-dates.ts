// admin/scripts/check-dates.ts
// Unit checks for the dashboard date-range foundation. Run with:
//   node scripts/check-dates.ts
// (Node >= 22.18 strips types by default; this folder is outside tsconfig's
//  `include`, so `tsc --noEmit` ignores it and only the UI consumes the lib.)
import {
  toDay, localStartIso, localEndIso, daysBetween, eachDay,
  normalizeRange, formatRangeLabel, todayRange, lastNDays, thisMonth,
  RANGE_PRESETS, autoGrain, bucketize,
} from '../src/features/dashboard/lib/dateRange.ts'

let failures = 0
function assert(cond: boolean, label: string, actual?: unknown) {
  if (cond) {
    console.log(`ok   ${label}`)
  } else {
    failures++
    console.log(`FAIL ${label}${actual !== undefined ? ` — got ${JSON.stringify(actual)}` : ''}`)
  }
}

assert(toDay(new Date(2026, 0, 15)) === '2026-01-15', 'toDay builds from local calendar parts')
assert(toDay(new Date(2026, 8, 1)) === '2026-09-01', 'toDay Sep 1 (the old UTC slice printed 2026-08-31 in PH)')
assert(new Date(localStartIso('2026-01-15')).getDate() === 15, 'localStartIso is local midnight', localStartIso('2026-01-15'))
assert(new Date(localEndIso('2026-01-15')).getDate() === 15, 'localEndIso stays inside the local day', localEndIso('2026-01-15'))
assert(localEndIso('2026-01-15') > localStartIso('2026-01-15'), 'end bound sorts after start bound')
assert(daysBetween('2026-01-15', '2026-03-15') === 60, 'daysBetween Jan15–Mar15 = 60', daysBetween('2026-01-15', '2026-03-15'))

const days = eachDay('2026-01-15', '2026-03-15')
assert(days.length === 60 && days[0] === '2026-01-15' && days[59] === '2026-03-15', 'eachDay enumerates the range')

const swapped = normalizeRange('2026-03-15', '2026-01-15')
assert(swapped.start === '2026-01-15' && swapped.end === '2026-03-15', 'normalizeRange swaps inverted ranges')

assert(
  formatRangeLabel({ start: '2026-01-15', end: '2026-03-15' }) === 'Jan 15, 2026 - Mar 15, 2026',
  'formatRangeLabel',
  formatRangeLabel({ start: '2026-01-15', end: '2026-03-15' }),
)
assert(thisMonth(new Date(2026, 8, 27)).start === '2026-09-01', 'thisMonth start')
assert(thisMonth(new Date(2026, 8, 27)).end === '2026-09-30', 'thisMonth end')
assert(lastNDays(30, new Date(2026, 8, 27)).start === '2026-08-29', 'lastNDays(30) start')
assert(todayRange(new Date(2026, 8, 27)).start === '2026-09-27', 'todayRange')
assert(RANGE_PRESETS.length === 7, 'all 7 presets present')

assert(autoGrain({ start: '2026-09-01', end: '2026-09-30' }) === 'daily', 'autoGrain: 30d → daily')
assert(autoGrain({ start: '2026-01-15', end: '2026-03-15' }) === 'weekly', 'autoGrain: 60d → weekly')
assert(autoGrain({ start: '2026-01-01', end: '2026-12-31' }) === 'monthly', 'autoGrain: 365d → monthly')

const m = bucketize({ start: '2026-01-15', end: '2026-03-15' }, 'monthly')
assert(m.map(b => b.key).join(',') === '2026-01,2026-02,2026-03', 'monthly bucket keys', m.map(b => b.key))
assert(m[0].start === '2026-01-15' && m[2].end === '2026-03-15', 'monthly buckets clipped to the range')

const w = bucketize({ start: '2026-01-15', end: '2026-03-15' }, 'weekly')
assert(w.length === 9 && w[0].start === '2026-01-15' && w[8].end === '2026-03-15', 'weekly buckets cover the range edge to edge')

const dSame = bucketize({ start: '2026-09-01', end: '2026-09-30' }, 'daily')
assert(dSame.length === 30 && dSame[0].label === '1' && dSame[29].label === '30', 'daily labels are day numbers in-month')

const dCross = bucketize({ start: '2026-01-15', end: '2026-02-10' }, 'daily')
assert(dCross[0].label === 'Jan 15' && dCross[dCross.length - 1].label === 'Feb 10', 'daily labels carry the month across months')

if (failures > 0) {
  console.log(`${failures} assertion(s) FAILED`)
  process.exit(1)
}
console.log('ALL DATE CHECKS PASSED')
