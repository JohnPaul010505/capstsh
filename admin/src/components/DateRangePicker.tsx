import { useEffect, useRef, useState } from 'react'
import { Calendar, ChevronDown } from 'lucide-react'
import { cn } from '@/lib/utils'
import { RANGE_PRESETS, formatRangeLabel, normalizeRange, toDay, type Range } from '@/features/dashboard/lib/dateRange'

interface DateRangePickerProps {
  value: Range
  onChange: (range: Range) => void
  className?: string
}

/**
 * Glass date-range filter: a calendar pill showing 'Jan 15, 2026 - Mar 15, 2026'
 * that opens a popover with native start/end date inputs plus quick presets.
 * Native inputs are used on purpose — their calendar popup is OS-handled and
 * cannot break the dashboard theme or throw chart-sizing errors.
 */
export default function DateRangePicker({ value, onChange, className }: DateRangePickerProps) {
  const [open, setOpen] = useState(false)
  const [draftStart, setDraftStart] = useState(value.start)
  const [draftEnd, setDraftEnd] = useState(value.end)
  const [error, setError] = useState<string | null>(null)
  const rootRef = useRef<HTMLDivElement>(null)
  const today = toDay(new Date())

  useEffect(() => {
    if (open) {
      setDraftStart(value.start)
      setDraftEnd(value.end)
      setError(null)
    }
  }, [open, value.start, value.end])

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

  const pickPreset = (apply: (today: Date) => Range) => {
    onChange(apply(new Date()))
    setOpen(false)
  }

  const applyCustom = () => {
    if (!draftStart || !draftEnd) {
      setError('Pick both a start and an end date.')
      return
    }
    if (draftStart > today || draftEnd > today) {
      setError('Dates cannot be in the future.')
      return
    }
    onChange(normalizeRange(draftStart, draftEnd))
    setOpen(false)
  }

  return (
    <div ref={rootRef} className={cn('relative', className)}>
      <button
        type="button"
        onClick={() => setOpen(o => !o)}
        className="flex items-center gap-2 px-3.5 py-2.5 glass-input rounded-xl text-sm text-fg-strong cursor-pointer hover:border-[#7C3AED]/50 focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50 transition-colors whitespace-nowrap"
        aria-haspopup="dialog"
        aria-expanded={open}
        aria-label={`Date range: ${formatRangeLabel(value)}. Change date range`}
      >
        <Calendar className="w-4 h-4 text-fg-muted shrink-0" />
        <span>{formatRangeLabel(value)}</span>
        <ChevronDown className={`w-4 h-4 text-fg-muted shrink-0 transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>
      {open && (
        <div className="glass-card absolute right-0 top-full mt-2 z-30 w-[19rem] rounded-xl border border-line p-3 shadow-xl" role="dialog" aria-label="Choose a date range">
          <div className="grid grid-cols-2 gap-2">
            <label className="block">
              <span className="text-[11px] font-medium text-fg-muted">Start date</span>
              <input
                type="date"
                value={draftStart}
                max={today}
                onChange={e => setDraftStart(e.target.value)}
                className="mt-1 w-full px-2.5 py-2 glass-input rounded-lg text-sm text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50"
              />
            </label>
            <label className="block">
              <span className="text-[11px] font-medium text-fg-muted">End date</span>
              <input
                type="date"
                value={draftEnd}
                max={today}
                onChange={e => setDraftEnd(e.target.value)}
                className="mt-1 w-full px-2.5 py-2 glass-input rounded-lg text-sm text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50"
              />
            </label>
          </div>
          <div className="mt-2 flex flex-wrap gap-1.5">
            {RANGE_PRESETS.map(p => (
              <button
                key={p.id}
                type="button"
                onClick={() => pickPreset(p.apply)}
                className="px-2.5 py-1 rounded-full text-[11px] font-medium glass-chip text-fg-muted hover:text-accent-purple hover:border-[#7C3AED]/50 cursor-pointer transition-colors"
              >
                {p.label}
              </button>
            ))}
          </div>
          {error && <p className="mt-2 text-[11px] text-[#EF4444]" role="alert">{error}</p>}
          <button
            type="button"
            onClick={applyCustom}
            className="mt-2.5 w-full px-3 py-2 rounded-lg text-sm font-semibold text-white bg-gradient-to-r from-[#7C3AED] to-[#8B5CF6] hover:brightness-110 cursor-pointer transition-all"
          >
            Apply range
          </button>
        </div>
      )}
    </div>
  )
}
