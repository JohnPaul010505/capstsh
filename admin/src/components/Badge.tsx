import type { ReactNode } from 'react'

export type BadgeTone = 'green' | 'amber' | 'blue' | 'purple' | 'red' | 'muted'

const TONES: Record<BadgeTone, string> = {
  green: 'bg-emerald-500/15 border border-emerald-400/25 text-accent-green',
  amber: 'bg-amber-500/15 border border-amber-400/25 text-accent-amber',
  blue: 'bg-blue-500/15 border border-blue-400/25 text-accent-blue',
  purple: 'bg-[#7C3AED]/15 border border-[#7C3AED]/30 text-accent-purple',
  red: 'bg-red-500/15 border border-red-400/25 text-[#F87171]',
  muted: 'bg-overlay-8 border border-line text-fg-muted',
}

/** Small pill used inside dashboard records tables (entry method, type, status). */
export default function Badge({ children, tone = 'muted' }: { children: ReactNode; tone?: BadgeTone }) {
  return (
    <span className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[11px] font-medium whitespace-nowrap ${TONES[tone]}`}>
      {children}
    </span>
  )
}
