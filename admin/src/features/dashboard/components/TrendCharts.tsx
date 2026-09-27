import {
  Bar, BarChart, CartesianGrid, Cell, Line, LineChart, Pie, PieChart,
  ResponsiveContainer, Tooltip, XAxis, YAxis,
} from 'recharts'
import { useChartTheme } from '@/hooks/useChartTheme'

export interface TrendPoint {
  key: string
  label: string
  full: string
  value: number
  /** Optional second series (Member Growth's cumulative line). */
  total?: number
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
 * Member Growth's dual-line chart: additions per bucket + running total.
 * Two different scales in one chart is misleading, so both lines share the
 * axis and the cumulative line is deliberately the light one.
 */
export function DualLineTrend({ points, ariaLabel }: { points: TrendPoint[]; ariaLabel: string }) {
  const t = useChartTheme()
  const interval = Math.max(0, Math.ceil(points.length / 12))
  const max = niceMax(points.map(p => Math.max(p.value, p.total ?? 0)))

  return (
    <div role="img" aria-label={ariaLabel} className="h-full w-full">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={points} margin={{ top: 6, right: 8, bottom: 0, left: -14 }}>
          <CartesianGrid strokeDasharray="3 3" stroke={t.grid} vertical={false} />
          <XAxis dataKey="label" tick={t.axisTick} interval={interval} axisLine={{ stroke: t.axisLine }} tickLine={false} />
          <YAxis tick={t.axisTick} axisLine={false} tickLine={false} width={44} allowDecimals={false} domain={[0, max]} />
          <Tooltip
            cursor={{ stroke: t.axisLine }}
            contentStyle={t.tooltipStyle}
            labelStyle={{ color: t.tooltipLabel }}
            labelFormatter={(_, payload) => (payload?.[0]?.payload as TrendPoint | undefined)?.full ?? ''}
          />
          <Line
            type="monotone" dataKey="value" name="New members"
            stroke="#7C3AED" strokeWidth={2.5} dot={points.length <= 40 ? { r: 2.5 } : false}
            activeDot={{ r: 4 }} isAnimationActive={false}
          />
          <Line
            type="monotone" dataKey="total" name="Cumulative total"
            stroke="#22C55E" strokeWidth={2} strokeDasharray="5 4" dot={false}
            activeDot={{ r: 4 }} isAnimationActive={false}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  )
}

export const SLICE_COLORS: Record<string, string> = {
  Active: '#22C55E',
  Inactive: '#EF4444',
  Male: '#3B82F6',
  Female: '#DB2777',
  Other: '#C084FC',
  Unspecified: '#94A3B8',
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
