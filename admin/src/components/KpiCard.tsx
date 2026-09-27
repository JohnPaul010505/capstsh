import { type LucideIcon } from 'lucide-react'

export type KpiTone = 'blue' | 'green' | 'purple' | 'amber'

const TONE_TILE: Record<KpiTone, string> = {
  blue: 'bg-[#3B82F6]/15 border border-[#3B82F6]/25 text-[#60A5FA]',
  green: 'bg-[#22C55E]/15 border border-[#22C55E]/25 text-[#34D399]',
  purple: 'bg-[#7C3AED]/20 border border-[#7C3AED]/25 text-accent-purple',
  amber: 'bg-[#F59E0B]/15 border border-[#F59E0B]/25 text-[#FBBF24]',
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
  icon: LucideIcon
  tone?: KpiTone
}

/**
 * Glass KPI card: icon tile on the left, title / value / sub-line stacked
 * on the right. Deliberately separate from StatsCard (top row), which keeps
 * its sparkline design; this one matches the dashboard tab mockups.
 */
export default function KpiCard({ title, value, sub, subTone = 'muted', icon: Icon, tone = 'purple' }: KpiCardProps) {
  return (
    <div className="glass-card rounded-2xl p-4 flex items-center gap-3.5 min-w-0">
      <span className={`flex items-center justify-center w-11 h-11 rounded-xl shrink-0 ${TONE_TILE[tone]}`}>
        <Icon className="w-5 h-5" strokeWidth={2} />
      </span>
      <div className="min-w-0">
        <p className="text-[12px] text-fg-muted truncate">{title}</p>
        <p className="text-[28px] font-bold text-fg-strong leading-tight truncate" title={value}>{value}</p>
        {sub && <p className={`text-[11px] font-medium truncate ${SUB_TONE[subTone]}`}>{sub}</p>}
      </div>
    </div>
  )
}
