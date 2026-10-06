import { useEffect, useRef, useState, type HTMLAttributes } from 'react'
import { ChevronDown } from 'lucide-react'
import { cn } from '@/lib/utils'

export type SelectOption = { id: string; label: string; disabled?: boolean }

/**
 * Glass-styled custom dropdown (native <select> popups render white and can't be themed).
 *
 * Reusable component extracted from MembershipsPage.tsx so both MembershipsPage
 * and PredictionsPage can render a themed dropdown without fighting native OS styling.
 */
export function MemberSelect({ options, value, onChange, placeholder = 'Select...', className, buttonClassName, searchable = false }: {
  options: SelectOption[] | undefined
  value: string
  onChange: (id: string) => void
  placeholder?: string
  className?: HTMLAttributes<HTMLDivElement>['className']
  /** Extra classes merged onto the trigger button (e.g. larger dashboard-filter sizing). */
  buttonClassName?: string
  /**
   * Renders a search box at the top of the open list and narrows the options as
   * you type.
   *
   * Off by default, because it is not free. The option list is whatever the
   * caller passed - for a member picker that is the full roster (987 members in
   * the seeded data), and the dashboard's own filters are short by nature, so a
   * text box above a five-item grain selector would be clutter. Predictions asks
   * for one member out of that same full roster, where scrolling to find them is
   * not a picker, so it opts in and the other callers are untouched.
   */
  searchable?: boolean
}) {
  const [open, setOpen] = useState(false)
  const [query, setQuery] = useState('')
  const rootRef = useRef<HTMLDivElement>(null)
  const searchRef = useRef<HTMLInputElement>(null)
  const selected = options?.find(o => o.id === value)

  /* Matched on the label, which is the whole string the reader sees - "Ada
     Mendoza (M034) - ada@demo.fit" - so one box covers name, member code and
     email without the caller having to say which of the three it expects. */
  const term = query.trim().toLowerCase()
  const visible = !searchable || !term
    ? options ?? []
    : (options ?? []).filter(o => o.label.toLowerCase().includes(term))

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

  /* Open with the caret already in the box, and start from a clean one each
     time. A term left over from the last open would silently hide most of the
     roster the moment the list is reopened, which reads as "the picker is
     broken" rather than "you still have a filter on". */
  useEffect(() => {
    if (!open) {
      setQuery('')
      return
    }
    if (searchable) searchRef.current?.focus()
  }, [open, searchable])

  return (
    <div ref={rootRef} className={cn('relative', className)}>
      <button
        type="button"
        onClick={() => setOpen(o => !o)}
        className={cn(
          'w-full flex items-center justify-between gap-2 px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-left cursor-pointer hover:border-[#7C3AED]/50 focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50 transition-colors',
          buttonClassName,
        )}
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
          {searchable && (
            /* Sticky, because the list scrolls UNDER it: 987 members is a long
               scroll, and a filter that scrolls out of sight is no use. */
            <div className="sticky top-0 z-10 bg-[var(--table-head-bg)] px-2 pt-2 pb-1.5">
              <input
                ref={searchRef}
                type="text"
                value={query}
                onChange={e => setQuery(e.target.value)}
                onKeyDown={e => { if (e.key === 'Enter') setOpen(false) }}
                placeholder="Search name, code or email…"
                aria-label="Search members"
                className="w-full px-3 py-1.5 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong placeholder:text-fg-faint focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50"
              />
            </div>
          )}
          <button
            type="button"
            onClick={() => { onChange(''); setOpen(false) }}
            className={`w-full text-left px-3 py-2 text-sm cursor-pointer transition-colors whitespace-nowrap ${!value ? 'bg-[#7C3AED]/15 text-accent-purple' : 'text-fg-muted hover:bg-[#7C3AED]/10 hover:text-fg-strong'}`}
          >
            {placeholder}
          </button>
          {visible.length === 0 && (
            <p className="px-3 py-2 text-sm text-fg-faint">No members match &ldquo;{query.trim()}&rdquo;</p>
          )}
          {visible.map(opt => (
            <button
              key={opt.id}
              type="button"
              // A disabled option stays VISIBLE (dimmed, with the reason in its
              // title) rather than being dropped from the list: silently
              // removing "Daily" would leave a reader wondering where it went,
              // and it is still the truth that the range cannot show it.
              disabled={opt.disabled}
              title={opt.disabled ? 'Not available for this date range' : opt.label}
              onClick={() => { if (opt.disabled) return; onChange(opt.id); setOpen(false) }}
              className={`w-full text-left px-3 py-2 text-sm transition-colors whitespace-nowrap ${
                opt.disabled
                  ? 'text-fg-faint cursor-not-allowed'
                  : `cursor-pointer ${opt.id === value ? 'bg-[#7C3AED]/15 text-accent-purple' : 'text-fg hover:bg-[#7C3AED]/10 hover:text-fg-strong'}`
              }`}
            >
              {opt.label}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
