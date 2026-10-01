import type { ReactNode } from 'react'
import { LineChart as ChartIcon, Inbox } from 'lucide-react'
import { MemberSelect } from '@/components/MemberSelect'
import type { Grain } from '@/features/dashboard/lib/dateRange'

/**
 * Chart box height for the dashboard tabs, as Tailwind classes rather than
 * pixels.
 *
 * Two constraints fight here. The chart must not be `flex-1` beside a
 * `flex-1` table - that 50/50 split left the table about three rows tall -
 * but a fixed 200px chart plus the header, the KPI row and the table's own
 * 16rem floor OVERFLOWED a 768px-tall viewport by ~100px, which the release
 * gate correctly reports as clipped content. So the height follows the
 * viewport: short windows get a shorter chart, tall ones get the full box.
 *
 * These are arbitrary variants, which Tailwind v3.4 supports.
 */
export const TREND_CHART_HEIGHT =
  'h-[84px] [@media(min-height:700px)]:h-[104px] [@media(min-height:760px)]:h-[128px] [@media(min-height:850px)]:h-[160px] [@media(min-height:950px)]:h-[200px]'

export const GRAIN_OPTIONS = [
  { id: 'daily', label: 'Daily' },
  { id: 'weekly', label: 'Weekly' },
  { id: 'monthly', label: 'Monthly' },
] as const

interface TrendChartCardProps {
  title: string
  /** Renders the Daily/Weekly/Monthly granularity dropdown when present. */
  grain?: Grain
  /**
   * Grains the current range can actually draw (`grainsForRange`). Anything
   * outside this list is shown but disabled.
   *
   * The dropdown used to offer Daily over a 1,369-day All-time range, which
   * rendered 1,369 bars in ~1,700px - about one pixel each, on a 0..1 axis. The
   * option is dimmed rather than removed so the reason stays visible, and
   * disabling it beats clamping the value silently, which would leave the
   * dropdown reading "Daily" over a monthly chart.
   */
  grainOptions?: Grain[]
  onGrainChange?: (g: Grain) => void
  isLoading?: boolean
  /** True when the selected range produced no data — shows guidance, never a 0×0 chart. */
  isEmpty?: boolean
  emptyMessage?: string
  ariaLabel?: string
  /**
   * Fixed chart height. Omit it to let the chart fill and SHRINK with the
   * available space (`flex-1 min-h-0`), which is what the no-scroll dashboard
   * layout needs: a pinned 260px box makes the panel taller than the viewport,
   * and `overflow-hidden` on the parent then silently clips the bottom of the
   * page instead of fitting it.
   *
   * The `min-h` floor keeps real pixels in the box even if an ancestor collapses,
   * which is what stops Recharts from ever measuring 0×0.
   */
  height?: number
  /**
   * Responsive alternative to `height`, as Tailwind classes. Preferred: it can
   * follow the viewport height, which a pixel value cannot.
   */
  heightClass?: string
  children?: ReactNode
}

/**
 * Glass trend-chart card with a pinned title row and a chart box.
 *
 * The chart box plus the `isEmpty` guard is the anti-"widget error" contract: a
 * ResponsiveContainer with 0 width/height (Recharts' classic rendering
 * exception) can only be mounted once the box has real pixels, so an empty or
 * still-loading range renders the empty state instead of the chart tree.
 */
export default function TrendChartCard({
  title, grain, grainOptions, onGrainChange, isLoading, isEmpty, emptyMessage,
  ariaLabel, height, heightClass, children,
}: TrendChartCardProps) {
  const fill = height === undefined && heightClass === undefined
  return (
    <section
      className={`glass-panel rounded-2xl p-4 ${fill ? 'flex flex-col flex-1 min-h-[9.5rem] min-w-0' : ''}`}
      aria-label={ariaLabel ?? title}
    >
      <div className="flex flex-wrap items-center justify-between gap-2 mb-3 shrink-0">
        <div className="flex items-center gap-2.5">
          {/* Solid purple with a white glyph, matching `KpiCard`'s tile: the
              card's own icon used to be a 15% purple wash behind a lavender
              glyph, which is the same purple at two different strengths - a
              tint against a tint on the same surface. */}
          <span className="flex items-center justify-center w-7 h-7 rounded-lg bg-[#7C3AED] text-white shrink-0">
            <ChartIcon className="h-3.5 w-3.5" strokeWidth={2} />
          </span>
          <h2 className="text-[15px] font-semibold text-fg-strong">{title}</h2>
        </div>
        {grain && onGrainChange && (
          <MemberSelect
            options={GRAIN_OPTIONS.map(g => ({
              id: g.id,
              label: g.label,
              disabled: grainOptions ? !grainOptions.includes(g.id as Grain) : false,
            }))}
            value={grain}
            onChange={g => onGrainChange(g as Grain)}
            className="w-32"
            buttonClassName="px-3 py-2 rounded-lg text-xs"
          />
        )}
      </div>

      <div
        style={fill || heightClass ? undefined : { height }}
        className={fill ? 'w-full flex-1 min-h-0' : `w-full ${heightClass ?? ''}`}
      >

        {isLoading ? (
          <div className="h-full w-full flex items-end gap-2 animate-pulse" aria-hidden="true">
            {[35, 62, 48, 80, 40, 70, 52, 90, 45, 58].map((h, i) => (
              <div key={i} className="flex-1 rounded-t-md bg-skeleton" style={{ height: `${h}%` }} />
            ))}
          </div>
        ) : isEmpty ? (
          <div className="h-full w-full flex flex-col items-center justify-center gap-2 text-center px-6">
            <span className="flex items-center justify-center w-10 h-10 rounded-full bg-overlay-8 text-fg-faint">
              <Inbox className="w-5 h-5" strokeWidth={1.75} />
            </span>
            <p className="text-[13px] text-fg-muted">{emptyMessage ?? 'No data in the selected range'}</p>
            <p className="text-[11px] text-fg-faint">Adjust the date range or filter above to widen the window.</p>
          </div>
        ) : children}
      </div>
    </section>
  )
}
