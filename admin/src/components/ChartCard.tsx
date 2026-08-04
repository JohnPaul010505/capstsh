import type { ReactNode } from 'react'
import { type LucideIcon, Inbox } from 'lucide-react'

interface ChartCardProps {
  title: string
  icon: LucideIcon
  badge?: ReactNode

  isLoading?: boolean
  isEmpty?: boolean
  emptyMessage?: string
  ariaLabel?: string
  footer?: ReactNode
  children: ReactNode
}

export default function ChartCard({ title, icon: Icon, badge, isLoading, isEmpty, emptyMessage, ariaLabel, footer, children }: ChartCardProps) {
  const showFooter = footer && !isLoading && !isEmpty
  return (
    <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm transition-colors hover:border-[#38385C]">
      <div className="flex items-start justify-between mb-4 gap-3">
        <div className="flex items-center gap-2.5">
          <span className="flex items-center justify-center w-8 h-8 rounded-lg bg-[#7C3AED]/15 text-[#C084FC] shrink-0">
            <Icon className="w-4 h-4" strokeWidth={2} />
          </span>
          <h2 className="text-lg font-semibold text-[#ECECFC]">{title}</h2>
        </div>
        {badge}
      </div>
      <div className="h-72 relative" role="img" aria-label={ariaLabel ?? title}>
        {isLoading ? (
          <div className="h-full w-full flex items-end gap-2 animate-pulse" aria-hidden="true">
            {[35, 62, 48, 80, 40, 70, 52, 90, 45, 58].map((h, i) => (
              <div key={i} className="flex-1 rounded-t-md bg-[#1F1F3D]" style={{ height: `${h}%` }} />
            ))}
          </div>
        ) : isEmpty ? (
          <div className="h-full w-full flex flex-col items-center justify-center gap-2 text-center px-6">
            <span className="flex items-center justify-center w-10 h-10 rounded-full bg-white/[0.08] text-[#5A5A82]">
              <Inbox className="w-5 h-5" strokeWidth={1.75} />
            </span>
            <p className="text-sm text-[#8888B3]">{emptyMessage ?? 'No data yet'}</p>
          </div>
        ) : children}
      </div>
      {showFooter ? <div className="mt-4 pt-4 border-t border-white/10">{footer}</div> : null}
    </div>
  )
}
