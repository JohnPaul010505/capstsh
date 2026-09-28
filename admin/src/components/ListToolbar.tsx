import { useEffect, useRef, useState } from 'react'
import { Search, X, Calendar } from 'lucide-react'

/**
 * Search + date-range toolbar shared by the members, trainers and memberships
 * pages, so all three read identically and behave identically.
 *
 * The search box is DEBOUNCED. Sending every keystroke to PostgREST means a
 * request per character; on a 987-row table that is dozens of round trips for
 * one word, and the last response to arrive is not necessarily the last one
 * sent, so the list can settle on a stale result.
 */
export interface ListToolbarProps {
  search: string
  onSearchChange: (value: string) => void
  /** 'YYYY-MM-DD' inclusive bounds, or undefined for "no filter". */
  from?: string
  to?: string
  onDateRangeChange?: (from: string | undefined, to: string | undefined) => void
  /** What the date bound applies to, e.g. "Joined" — used in the label. */
  dateLabel?: string
  placeholder?: string
  /** Extra controls rendered on the right (tab switcher, buttons). */
  children?: React.ReactNode
  debounceMs?: number
}

export default function ListToolbar({
  search, onSearchChange, from, to, onDateRangeChange,
  dateLabel = 'Date', placeholder = 'Search…', children, debounceMs = 300,
}: ListToolbarProps) {
  const [draft, setDraft] = useState(search)
  const [showDates, setShowDates] = useState(Boolean(from || to))

  // Debounce the outward value only; the input stays controlled by `draft` so
  // typing never feels laggy.
  useEffect(() => {
    if (draft === search) return
    const id = window.setTimeout(() => onSearchChange(draft), debounceMs)
    return () => window.clearTimeout(id)
  }, [draft, search, onSearchChange, debounceMs])

  // Adopt an EXTERNAL reset (e.g. a "clear filters" button elsewhere in the
  // page) without fighting the user mid-word.
  //
  // Comparing to a ref of the last-seen prop, not to '' directly: during the
  // 300ms debounce `search` is still '' while the user has already typed, so a
  // naive `search === '' && draft !== ''` test cleared the box after the FIRST
  // character and no query was ever sent.
  const lastSearch = useRef(search)
  useEffect(() => {
    if (lastSearch.current !== search) {
      lastSearch.current = search
      if (search === '' && draft !== '') setDraft('')
    }
  }, [search, draft])

  const hasDates = Boolean(from || to)
  const change = (next: { from?: string; to?: string }) => onDateRangeChange?.(next.from, next.to)

  return (
    <div className="flex flex-wrap items-center gap-2 shrink-0">
      <div className="relative flex-1 min-w-[14rem] max-w-sm">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-fg-faint pointer-events-none" />
        <input
          type="search"
          value={draft}
          onChange={e => setDraft(e.target.value)}
          placeholder={placeholder}
          aria-label={placeholder}
          className="w-full pl-9 pr-8 py-2 glass-input rounded-xl text-sm text-fg-strong placeholder:text-fg-faint focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50"
        />
        {draft && (
          <button
            type="button"
            onClick={() => setDraft('')}
            aria-label="Clear search"
            className="absolute right-2.5 top-1/2 -translate-y-1/2 text-fg-faint hover:text-fg cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        )}
      </div>

      {onDateRangeChange && (
        <>
          <button
            type="button"
            onClick={() => { setShowDates(v => !v); if (showDates) change({}) }}
            aria-pressed={showDates}
            className={`flex items-center gap-1.5 px-3 py-2 rounded-xl text-sm border transition-colors cursor-pointer ${
              hasDates
                ? 'border-[#7C3AED]/60 text-fg-strong bg-[#7C3AED]/10'
                : 'bg-overlay-8 border-line text-fg-muted hover:border-fg-muted'
            }`}
          >
            <Calendar className="w-4 h-4" />
            {dateLabel}
            {hasDates && <span className="text-[11px] text-fg-muted">· {from || '…'} → {to || '…'}</span>}
          </button>

          {showDates && (
            <div className="flex items-center gap-2">
              <input
                type="date"
                value={from ?? ''}
                max={to}
                onChange={e => change({ from: e.target.value || undefined, to })}
                aria-label={`${dateLabel} from`}
                className="px-2.5 py-2 glass-input rounded-xl text-sm text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50"
              />
              <span className="text-fg-faint text-sm">→</span>
              <input
                type="date"
                value={to ?? ''}
                min={from}
                onChange={e => change({ from, to: e.target.value || undefined })}
                aria-label={`${dateLabel} to`}
                className="px-2.5 py-2 glass-input rounded-xl text-sm text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50"
              />
              {hasDates && (
                <button
                  type="button"
                  onClick={() => change({})}
                  aria-label="Clear date filter"
                  className="p-1.5 rounded-lg glass-chip cursor-pointer hover:border-[#7C3AED]/50"
                >
                  <X className="w-4 h-4" />
                </button>
              )}
            </div>
          )}
        </>
      )}

      <div className="flex items-center gap-2 ml-auto">{children}</div>
    </div>
  )
}
