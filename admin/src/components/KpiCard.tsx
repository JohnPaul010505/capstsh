import { type LucideIcon } from 'lucide-react'

export type KpiTone = 'blue' | 'green' | 'purple' | 'amber'

/**
 * The one tile every KPI card uses: solid brand purple, white glyph.
 *
 * The four cards on a tab used to be tinted per tone - purple, blue, amber and
 * green, each a ~15% wash of its own hue behind a bright glyph - so four
 * competing tints read as four unrelated widgets rather than one row, and the
 * one thing they agreed on (this is the dashboard's own accent) was the thing
 * they spent that agreement on. Solid purple with a white glyph says "same row"
 * at a glance and matches the selected tab pill and the chart card's own tile.
 */
const KPI_TILE = 'bg-[#7C3AED] text-white'

/**
 * `KpiTone` stays part of this component's public shape - five panels plus the
 * Coach Feedback rating card pass one - so every tone resolves to the same tile
 * rather than the call sites being churned to remove a prop that now says
 * nothing.
 */
const TONE_TILE: Record<KpiTone, string> = {
  blue: KPI_TILE,
  green: KPI_TILE,
  purple: KPI_TILE,
  amber: KPI_TILE,
}

export type KpiSubTone = 'up' | 'down' | 'muted'

const SUB_TONE: Record<KpiSubTone, string> = {
  up: 'text-accent-green',
  down: 'text-[#EF4444]',
  muted: 'text-fg-muted',
}

interface KpiCardProps {
  title: string
  value: string
  /** Secondary line (e.g. '+12% vs previous 30 days' or 'across 60 days'). */
  sub?: string
  subTone?: KpiSubTone
  /**
   * A 0-5 rating shown beside the value, as filled then empty stars.
   *
   * Added for the Coach Feedback page, which was the one place in the app that
   * hand-rolled a star row instead of reaching for this component - so its
   * average rating read as a different app from the KPIs beside it. Optional,
   * and unused by the dashboard's own cards, which report counts.
   */
  stars?: number | null
  icon: LucideIcon
  tone?: KpiTone
  /**
   * True while this tab's data is still in flight.
   *
   * Every dashboard KPI is derived from a whole-table fetch, so a loading
   * card used to render a confident "0" that actually meant "not loaded yet".
   * On the All time preset that was a 16-second lie on all four cards at once.
   * While loading the card shows an em dash and a pulsing bar instead, and
   * aria-busy so assistive tech is told the number is in flight.
   */
  isLoading?: boolean
}

/**
 * Glass KPI card: icon tile on the left, title / value / sub-line stacked
 * on the right. Deliberately separate from StatsCard (top row), which keeps
 * its sparkline design; this one matches the dashboard tab mockups.
 */
export default function KpiCard({ title, value, sub, subTone = 'muted', stars, icon: Icon, tone = 'purple', isLoading = false }: KpiCardProps) {
  return (
    <div className="glass-card rounded-2xl p-4 flex items-center gap-3.5 min-w-0" aria-busy={isLoading}>
      <span className={`flex items-center justify-center w-11 h-11 rounded-xl shrink-0 ${TONE_TILE[tone]}`}>
        <Icon className="w-5 h-5" strokeWidth={2} />
      </span>
      <div className="min-w-0">
        <p className="text-[12px] text-fg-muted truncate">{title}</p>
        {isLoading ? (
          <>
            <p className="text-[28px] font-bold text-fg-faint leading-tight">—</p>
            <div className="mt-1.5 h-2.5 w-24 rounded-full bg-skeleton animate-pulse" />
            <span className="sr-only">Loading</span>
          </>
        ) : (
          <>
            {/* The value and its stars share one line, so a rating card stays the
                height of every other card instead of growing a third row for the
                glyphs. Clamped because a 4.6 average rounds to 5 and a bad row
                would otherwise print six stars. */}
            <div className="flex items-center gap-2 min-w-0">
              <p className="text-[28px] font-bold text-fg-strong leading-tight truncate tabular-nums" title={value}>{value}</p>
              {stars != null && (() => {
                const filled = Math.min(5, Math.max(0, Math.round(stars)))
                return (
                  <span role="img" aria-label={`${filled} out of 5`} title={`${filled} out of 5`} className="text-[15px] tracking-wide shrink-0">
                    <span className="text-[#FFC107]">{'★'.repeat(filled)}</span>
                    <span className="text-fg-faint">{'★'.repeat(5 - filled)}</span>
                  </span>
                )
              })()}
            </div>
            {sub && <p className={`text-[11px] font-medium truncate ${SUB_TONE[subTone]}`}>{sub}</p>}
          </>
        )}
      </div>
    </div>
  )
}
