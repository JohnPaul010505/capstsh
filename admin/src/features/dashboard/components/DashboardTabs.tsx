import { useRef, type KeyboardEvent } from 'react'
import { type LucideIcon } from 'lucide-react'
import { cn } from '@/lib/utils'

export interface TabDef {
  id: string
  label: string
  icon: LucideIcon
}

interface DashboardTabsProps {
  tabs: TabDef[]
  value: string
  onChange: (id: string) => void
}

/**
 * Horizontal pill tab bar for the dashboard sub-pages.
 *
 * Real ARIA tablist: `aria-selected`, roving focus, Left/Right/Home/End
 * navigation, and a visible focus ring — the five mockup screens are one
 * page with five tabs, not five routes, so the semantics have to carry the
 * interaction instead of the URL.
 */
export default function DashboardTabs({ tabs, value, onChange }: DashboardTabsProps) {
  const btns = useRef<(HTMLButtonElement | null)[]>([])

  const onKeyDown = (e: KeyboardEvent<HTMLButtonElement>, index: number) => {
    const last = tabs.length - 1
    let next: number | null = null
    if (e.key === 'ArrowRight') next = index === last ? 0 : index + 1
    else if (e.key === 'ArrowLeft') next = index === 0 ? last : index - 1
    else if (e.key === 'Home') next = 0
    else if (e.key === 'End') next = last
    if (next === null) return
    e.preventDefault()
    onChange(tabs[next].id)
    btns.current[next]?.focus()
  }

  return (
    <div role="tablist" aria-label="Dashboard sections" className="flex flex-wrap gap-1.5 p-1 glass-card rounded-2xl">
      {tabs.map((t, i) => {
        const active = t.id === value
        return (
          <button
            key={t.id}
            ref={el => { btns.current[i] = el }}
            type="button"
            role="tab"
            id={`dash-tab-${t.id}`}
            aria-selected={active}
            aria-controls={`dash-panel-${t.id}`}
            tabIndex={active ? 0 : -1}
            onClick={() => onChange(t.id)}
            onKeyDown={e => onKeyDown(e, i)}
            className={cn(
              'flex items-center gap-2 px-3.5 py-2 rounded-xl text-[13px] font-medium whitespace-nowrap cursor-pointer transition-all duration-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#7C3AED]/60',
              active
                ? 'bg-gradient-to-r from-[#7C3AED] to-[#8B5CF6] text-white shadow-lg shadow-[#7C3AED]/30'
                : 'text-fg-muted hover:text-fg-strong hover:bg-[#7C3AED]/10',
            )}
          >
            {/* The icon paints its OWN colour rather than inheriting the button's,
                because the two states ask for different ones: purple while the
                tab is unselected, white once it is (the active pill is a purple
                gradient, so white is the only glyph colour that reads on it).
                No tile, no background - this is a recolour of the glyph, and
                the label keeps `text-fg-muted` / `hover:text-fg-strong` as it
                was. Setting the colour here also stops the button's
                `hover:text-fg-strong` from bleeding into the glyph, so the icon
                stays purple for as long as the tab is unselected. */}
            <t.icon className={cn('w-4 h-4 shrink-0', active ? 'text-white' : 'text-[#7C3AED]')} strokeWidth={2} />
            {t.label}
          </button>
        )
      })}
    </div>
  )
}
