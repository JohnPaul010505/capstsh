import { useEffect, useRef, useState, type HTMLAttributes } from 'react'
import { ChevronDown } from 'lucide-react'
import { cn } from '@/lib/utils'

export type SelectOption = { id: string; label: string }

/**
 * Glass-styled custom dropdown (native <select> popups render white and can't be themed).
 *
 * Reusable component extracted from MembershipsPage.tsx so both MembershipsPage
 * and PredictionsPage can render a themed dropdown without fighting native OS styling.
 */
export function MemberSelect({ options, value, onChange, placeholder = 'Select...', className }: {
  options: SelectOption[] | undefined
  value: string
  onChange: (id: string) => void
  placeholder?: string
  className?: HTMLAttributes<HTMLDivElement>['className']
}) {
  const [open, setOpen] = useState(false)
  const rootRef = useRef<HTMLDivElement>(null)
  const selected = options?.find(o => o.id === value)

  useEffect(() => {
    if (!open) return
    const onPointerDown = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false)
    }
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false)
    }
    document.addEventListener('mousedown', onPointerDown)
    document.addEventListener('keydown', onKeyDown)
    return () => {
      document.removeEventListener('mousedown', onPointerDown)
      document.removeEventListener('keydown', onKeyDown)
    }
  }, [open])

  return (
    <div ref={rootRef} className={cn('relative', className)}>
      <button
        type="button"
        onClick={() => setOpen(o => !o)}
        className="w-full flex items-center justify-between gap-2 px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-left cursor-pointer hover:border-[#7C3AED]/50 focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50 transition-colors"
        title={selected ? selected.label : placeholder}
        aria-haspopup="listbox"
        aria-expanded={open}
      >
        <span className={`truncate ${selected ? 'text-fg-strong' : 'text-fg-muted'}`}>
          {selected ? selected.label : placeholder}
        </span>
        <ChevronDown className={`w-4 h-4 text-fg-muted shrink-0 transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>
      {open && (
        <div className="glass-card absolute left-0 top-full mt-1 z-30 min-w-full w-max max-w-[min(90vw,32rem)] max-h-56 overflow-y-auto rounded-lg border border-line py-1 shadow-xl">
          <button
            type="button"
            onClick={() => { onChange(''); setOpen(false) }}
            className={`w-full text-left px-3 py-2 text-sm cursor-pointer transition-colors whitespace-nowrap ${!value ? 'bg-[#7C3AED]/15 text-accent-purple' : 'text-fg-muted hover:bg-[#7C3AED]/10 hover:text-fg-strong'}`}
          >
            {placeholder}
          </button>
          {options?.map(opt => (
            <button
              key={opt.id}
              type="button"
              onClick={() => { onChange(opt.id); setOpen(false) }}
              className={`w-full text-left px-3 py-2 text-sm cursor-pointer transition-colors whitespace-nowrap ${opt.id === value ? 'bg-[#7C3AED]/15 text-accent-purple' : 'text-fg hover:bg-[#7C3AED]/10 hover:text-fg-strong'}`}
            >
              {opt.label}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
