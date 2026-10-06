import {
  Area, AreaChart, Bar, BarChart, CartesianGrid, Cell, Pie, PieChart,
  ResponsiveContainer, Tooltip, XAxis, YAxis,
} from 'recharts'
import { useChartTheme } from '@/hooks/useChartTheme'

export interface TrendPoint {
  key: string
  label: string
  full: string
  value: number
}

interface TrendProps {
  points: TrendPoint[]
  ariaLabel: string
  valueName: string
  /** Unique per chart instance so two charts on a page don't share a gradient. */
  gradientId?: string
}

const niceMax = (values: number[]) => Math.max(1, ...values)

/**
 * Fixed-box bar trend used by Daily Check-ins / Revenue / Recent Activity.
 *
 * Built from Recharts primitives only: no <ResponsiveContainer> sizing hacks,
 * no NaN axes — every point carries a numeric `value` and the parent renders
 * this only once its box has real pixels (see TrendChartCard).
 */
export function BarTrend({ points, ariaLabel, valueName, gradientId = 'trendBarGrad' }: TrendProps) {
  const t = useChartTheme()
  const interval = Math.max(0, Math.ceil(points.length / 12))

  return (
    <div role="img" aria-label={ariaLabel} className="h-full w-full">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={points} margin={{ top: 6, right: 8, bottom: 0, left: -14 }}>
          <defs>
            <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#7C3AED" />
              <stop offset="100%" stopColor="#A855F7" />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke={t.grid} vertical={false} />
          <XAxis
            dataKey="label"
            tick={t.axisTick}
            interval={interval}
            axisLine={{ stroke: t.axisLine }}
            tickLine={false}
          />
          <YAxis
            tick={t.axisTick}
            axisLine={false}
            tickLine={false}
            width={44}
            allowDecimals={false}
            domain={[0, niceMax(points.map(p => p.value))]}
          />
          <Tooltip
            cursor={{ fill: t.cursor }}
            contentStyle={t.tooltipStyle}
            labelStyle={{ color: t.tooltipLabel }}
            formatter={(v: number | string) => [Number(v) || 0, valueName]}
            labelFormatter={(_, payload) => (payload?.[0]?.payload as TrendPoint | undefined)?.full ?? ''}
          />
          <Bar dataKey="value" fill={`url(#${gradientId})`} radius={[4, 4, 0, 0]} isAnimationActive={false} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}

/**
 * Member Growth's chart: a filled area for new signups over time.
 *
 * This replaced a dual-line chart that plotted daily signups and the running
 * membership total on ONE shared axis. The two series differ by orders of
 * magnitude (tens of signups against a roster in the hundreds), so the daily
 * line was flattened against the axis and the cumulative line dominated the
 * whole panel - the chart was technically correct and practically unreadable.
 *
 * The area makes the SHAPE of growth legible (a spike, a steady ramp, a lull),
 * which is the actual question this tab answers. The dashed "Avg" benchmark
 * line that used to cut across it was removed on request: the KPI row already
 * states the averages, and a horizontal line through a 0..N wave read as a
 * defect rather than as context.
 */
export function GrowthAreaTrend({ points, ariaLabel, gradientId = 'growthGrad' }: {
  points: TrendPoint[]
  ariaLabel: string
  gradientId?: string
}) {
  const t = useChartTheme()
  const interval = Math.max(0, Math.ceil(points.length / 12))
  // The ceiling used to sit EXACTLY on the tallest point (domain [0, max]), so
  // every plateau - a run of equal days, which is what a spread roster gives -
  // was shaved flush against the top gridline and the wave read as cut off.
  // 25% of headroom keeps the peak inside the frame; `allowDecimals` stays
  // false on the axis below, so the extra room never buys a 1.5-member tick.
  const max = Math.ceil(niceMax(points.map(p => p.value)) * 1.25)

  return (
    <div role="img" aria-label={ariaLabel} className="h-full w-full">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={points} margin={{ top: 6, right: 8, bottom: 0, left: -14 }}>
          <defs>
            <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#7C3AED" stopOpacity={0.55} />
              <stop offset="100%" stopColor="#7C3AED" stopOpacity={0.04} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke={t.grid} vertical={false} />
          <XAxis dataKey="label" tick={t.axisTick} interval={interval} axisLine={{ stroke: t.axisLine }} tickLine={false} />
          <YAxis tick={t.axisTick} axisLine={false} tickLine={false} width={44} allowDecimals={false} domain={[0, max]} />
          <Tooltip
            cursor={{ stroke: t.axisLine }}
            contentStyle={t.tooltipStyle}
            labelStyle={{ color: t.tooltipLabel }}
            formatter={(v: number | string) => [Number(v) || 0, 'New members']}
            labelFormatter={(_, payload) => (payload?.[0]?.payload as TrendPoint | undefined)?.full ?? ''}
          />

          <Area
            type="monotone" dataKey="value" name="New members"
            stroke="#7C3AED" strokeWidth={2.5}
            fill={`url(#${gradientId})`}
            dot={points.length <= 40 ? { r: 2.5 } : false}
            activeDot={{ r: 4 }} isAnimationActive={false}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  )
}

/**
 * One palette per dimension, not one hue per label.
 *
 * These were six unrelated colours picked label by label, and the result read as
 * a rainbow with no hierarchy: nothing in the card said which pairs belonged to
 * the same dimension, the status pair (green/red) shouted louder than the rest,
 * and "Unspecified" - an empty value, not a group - was given a full slice and a
 * legend row so that 3 members out of 987 read as a category.
 *
 * Status is now a complementary green/rose pair, so the nested inner ring reads
 * as two distinct states at the size it is actually drawn rather than as one
 * warm band. It still speaks the same language as the two KPI cards above it -
 * green for the members who visited - even though the "did not visit" hue has
 * moved off amber to the complement of the green beside it.
 *
 * Gender is a
 * single violet ramp, the two real categories at either end, which makes the
 * dimension legible as a family instead of as two unrelated dots.
 */
export const SLICE_COLORS: Record<string, string> = {
  Active: '#22C55E',
  // Green's complement, not amber. Green and amber sit about 40 degrees apart
  // on the wheel, so they are the same warm blur at the size this arc actually
  // renders - the inner ring is a ~13px band at the layout's smallest - and
  // 771 inactive against 216 active read as one orange lump rather than as two
  // facts. Rose is the opposite hue of the green beside it, so the two arcs
  // separate at any size, and the legend dots and the proportional bar under
  // "Activity Status" - which read the same constant - follow it.
  Inactive: '#F43F5E',
  Male: '#7C3AED',
  Female: '#C084FC',
  Other: '#8B5CF6',
}

/**
 * Member Overview's gender/status donut with an inline legend.
 * The legend doubles as the accessible label — a pie alone is not readable.
 */
export function StatusDonut({ slices, ariaLabel, emptyMessage }: {
  slices: { name: string; value: number }[]
  ariaLabel: string
  emptyMessage?: string
}) {
  const t = useChartTheme()
  const total = slices.reduce((s, x) => s + x.value, 0)

  if (total === 0) {
    return (
      <div className="h-full w-full flex items-center justify-center">
        <p className="text-[13px] text-fg-muted">{emptyMessage ?? 'No members in this range'}</p>
      </div>
    )
  }

  return (
    <div role="img" aria-label={ariaLabel} className="h-full w-full flex items-center gap-5 px-2">
      <div className="h-full flex-1 min-w-0">
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={slices}
              dataKey="value"
              nameKey="name"
              innerRadius="58%"
              outerRadius="86%"
              paddingAngle={2}
              stroke="none"
              isAnimationActive={false}
            >
              {slices.map(s => (
                <Cell key={s.name} fill={SLICE_COLORS[s.name] ?? '#7C3AED'} />
              ))}
            </Pie>
            <Tooltip
              contentStyle={t.tooltipStyle}
              labelStyle={{ color: t.tooltipLabel }}
              formatter={(v: number | string, name: string) => [Number(v) || 0, name]}
            />
          </PieChart>
        </ResponsiveContainer>
      </div>
      <ul className="w-44 shrink-0 flex flex-col gap-2.5">
        {slices.map(s => {
          const pct = Math.round((s.value / total) * 100)
          return (
            <li key={s.name} className="flex items-center gap-2.5">
              <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: SLICE_COLORS[s.name] ?? '#7C3AED' }} />
              <span className="text-[13px] text-fg-muted flex-1 truncate">{s.name}</span>
              <span className="text-[13px] font-semibold text-fg-strong tabular-nums">{s.value}</span>
              <span className="text-[11px] text-fg-faint w-8 text-right tabular-nums">{pct}%</span>
            </li>
          )
        })}
      </ul>
    </div>
  )
}

export interface BreakdownSlice {
  name: string
  value: number
}

/**
 * BOTH dimensions on the circle: gender on the outer ring, activity status on
 * a ring nested inside it, with the headline activity rate in the hole.
 *
 * Two rings rather than one, because the two dimensions are independent 100%s
 * and a single ring can only honestly carry one of them: a 50/50 gender split
 * and a 22/78 activity split drawn on one circle would be read as comparable
 * shares of a whole, which they are not. Nesting them says "two separate
 * wholes" without spending a second circle of horizontal space, which this
 * half-width card does not have.
 *
 * The outer ring is gender because it is the wider of the two bands and reads
 * first; the inner ring is activity because the KPI cards directly above this
 * chart are already about activity and the ring's centre repeats that rate, so
 * the eye arrives there next. The radii leave a hole large enough for the
 * centre label at the SMALLEST box this card ever takes (128px, so a 64px
 * radius and a ~27px hole) rather than only at 1080p.
 *
 * Both rings live in ONE <PieChart> on purpose: two charts would render two
 * `.recharts-wrapper`s, and the release gate asserts the ring is square and
 * sized against its box by measuring the first wrapper - so a second chart
 * would quietly halve what that assertion actually covers.
 *
 * The centre keeps the active rate. It is the one number in this card that is
 * not about gender, and it ties the ring to the KPIs above it - but it is HTML
 * rather than a Recharts <Label> so it inherits the theme tokens, stays legible
 * when the ring shrinks, and is pointer-events-none so it never swallows the
 * hover the sectors need.
 *
 * Radii are percentages, so the rings scale with the card instead of sitting at
 * a fixed size inside a box several times wider than it is tall - which is what
 * left the old donut marooned in the middle of half the card with a legend
 * beside it repeating the same five numbers.
 */
export function MemberDistributionDonut({ genderSlices, statusSlices, total, active, ariaLabel, emptyMessage }: {
  genderSlices: BreakdownSlice[]
  /** Active / Inactive, as the nested inner ring. */
  statusSlices: BreakdownSlice[]
  /** Everyone on the books under the current filters; the rate's denominator. */
  total: number
  /** Members who checked in inside the selected range; drives the centre label. */
  active: number
  ariaLabel: string
  emptyMessage?: string
}) {
  const t = useChartTheme()
  // Divided by the FULL roster, not by the gender subtotal: 222 active of 987
  // members is 22%, and 222 of the 984 whose gender is recorded would claim a
  // share of the circle the centre number does not describe.
  const rate = total > 0 ? Math.round((active / total) * 100) : 0

  if (total === 0) {
    return (
      <div className="h-full w-full flex items-center justify-center px-3 text-center">
        <p className="text-[13px] text-fg-muted">{emptyMessage ?? 'No members in this range'}</p>
      </div>
    )
  }

  // Every gender is missing is not an empty state, it is the one case where the
  // ring would silently imply "nobody" where the truth is "not recorded". The
  // counts beside it carry the same fact as "N not recorded"; say so here too.
  if (genderSlices.length === 0) {
    return (
      <div className="h-full w-full flex items-center justify-center px-3 text-center">
        <p className="text-[13px] text-fg-muted">No gender recorded</p>
      </div>
    )
  }

  return (
    <div role="img" aria-label={ariaLabel} className="relative h-full w-full">
      <ResponsiveContainer width="100%" height="100%">
        <PieChart>
          {/* One full circle, one dimension: every arc is exactly the share of
              the roster whose gender says it is. `Other` only appears when a
              member actually recorded one, and the hook drops zero-count
              categories so an empty segment never paints a stray pixel. */}
          {/* The OUTER ring: gender. 70-100% leaves a 30% band - at the
              smallest box (64px radius) that is ~19px, thin but a legible arc -
              and a 70% inner edge that clears the activity ring below. */}
          <Pie
            data={genderSlices}
            dataKey="value"
            nameKey="name"
            startAngle={90}
            endAngle={-270}
            innerRadius="70%"
            outerRadius="100%"
            paddingAngle={2}
            cornerRadius={6}
            stroke="none"
            isAnimationActive={false}
          >
            {genderSlices.map(s => (
              <Cell key={s.name} fill={SLICE_COLORS[s.name] ?? '#7C3AED'} />
            ))}
          </Pie>
          {/* The INNER ring: activity status, nested rather than placed beside
              the first. 42-62% is a narrower band so the two do not read as one
              thick ring with a seam, and its 42% inner edge is the hole the
              centre label sits in. The corner radius is smaller than the outer
              ring's for the same reason: at 128px this band is only ~13px, and
              a 6px radius on a 13px band rounds the arc into a lozenge.

              `cornerRadius`/`paddingAngle` are read off the SECTORS, so both
              rings still paint two `.recharts-sector`s each whatever these are
              set to - which is what the release gate counts. */}
          <Pie
            data={statusSlices}
            dataKey="value"
            nameKey="name"
            startAngle={90}
            endAngle={-270}
            innerRadius="42%"
            outerRadius="62%"
            paddingAngle={2}
            cornerRadius={4}
            stroke="none"
            isAnimationActive={false}
          >
            {statusSlices.map(s => (
              <Cell key={s.name} fill={SLICE_COLORS[s.name] ?? '#7C3AED'} />
            ))}
          </Pie>
          <Tooltip
            contentStyle={t.tooltipStyle}
            labelStyle={{ color: t.tooltipLabel }}
            formatter={(v: number | string, name: string) => [Number(v) || 0, name]}
          />
        </PieChart>
      </ResponsiveContainer>
      {/* The one number worth reading without hovering. It is HTML rather than
          a Recharts <Label> so it inherits the theme tokens and stays legible
          when the ring shrinks, and pointer-events-none so it never swallows
          the hover the sectors need. */}
      <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
        <span className="text-[20px] font-semibold leading-none text-fg-strong tabular-nums">{rate}%</span>
        <span className="mt-1 text-[10px] uppercase tracking-wide text-fg-faint">active</span>
      </div>
    </div>
  )
}
