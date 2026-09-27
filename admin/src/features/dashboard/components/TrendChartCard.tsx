import type { ReactNode } from 'react'
import { LineChart as ChartIcon, Inbox } from 'lucide-react'
import { MemberSelect } from '@/components/MemberSelect'
import type { Grain } from '@/features/dashboard/lib/dateRange'

export const GRAIN_OPTIONS = [
  { id: 'daily', label: 'Daily' },
  { id: 'weekly', label: 'Weekly' },
  { id: 'monthly', label: 'Monthly' },
] as const

interface TrendChartCardProps {
  title: string
  /** Renders the Daily/Weekly/Monthly granularity dropdown when present. */
  grain?: Grain
  onGrainChange?: (g: Grain) => void
  isLoading?: boolean
  /** True when the selected range produced no data — shows guidance, never a 0×0 chart. */
  isEmpty?: boolean
  emptyMessage?: string
  ariaLabel?: string
  /** Fixed chart height; the box exists before data arrives so Recharts never measures 0×0. */
  height?: number
  children?: ReactNode
}

/**
 * Glass trend-chart card with a pinned title row and a FIXED chart box.
 *
 * The fixed box + `isEmpty` guard is the anti-"widget error" contract: a
 * ResponsiveContainer with 0 width/height (Recharts' classic rendering
 * exception) can only be mounted once the box has real pixels, so an empty or
 * still-loading range renders the empty state instead of the chart tree.
 */
export default function TrendChartCard({
  title, grain, onGrainChange, isLoading, isEmpty, emptyMessage,
  ariaLabel, height = 260, children,
}: TrendChartCardProps) {
  return (
    <section className="glass-panel rounded-2xl p-4" aria-label={ariaLabel ?? title}>
      <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
        <div className="flex items-center gap-2.5">
          <span className="flex items-center justify-center w-7 h-7 rounded-lg bg-[#7C3AED]/15 text-accent-purple shrink-0">
            <ChartIcon className="w-3.5 h-3.5" strokeWidth={2} />
          </span>
          <h2 className="text-[15px] font-semibold text-fg-strong">{title}</h2>
        </div>
        {grain && onGrainChange && (
          <MemberSelect
            options={GRAIN_OPTIONS.map(g => ({ id: g.id, label: g.label }))}
            value={grain}
            onChange={g => onGrainChange(g as Grain)}
            className="w-32"
            buttonClassName="px-3 py-2 rounded-lg text-xs"
          />
        )}
      </div>

      <div style={{ height }} className="w-full">
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
