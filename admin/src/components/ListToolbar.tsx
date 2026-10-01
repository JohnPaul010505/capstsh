import { useState } from 'react'
import { X, Calendar } from 'lucide-react'

/**
 * The strip of page-level controls that sits ABOVE the list card, shared by the
 * members, trainers and memberships pages so all three read identically.
 *
 * It used to own the search box too. It does not any more: the search now lives
 * in the card's own header, where the QR queue and every dashboard tab have
 * always kept theirs, so a reader moving between pages finds the box in the same
 * place on all of them. The debounce moved with it, into `PeopleTable` - it is
 * still there for the same reason (one PostgREST round trip per word, not per
 * character), just owned by the component that now renders the input.
 *
 * What is left here is what has no home inside a table card: the date-range
 * filter and the page's one action button.
 */
export interface ListToolbarProps {
  /** 'YYYY-MM-DD' inclusive bounds, or undefined for "no filter". */
  from?: string
  to?: string
  onDateRangeChange?: (from: string | undefined, to: string | undefined) => void
  /** What the date bound applies to, e.g. "Joined" — used in the label. */
  dateLabel?: string
  /** Extra controls rendered on the right (a page action button). */
  children?: React.ReactNode
}

export default function ListToolbar({
  from, to, onDateRangeChange, dateLabel = 'Date', children,
}: ListToolbarProps) {
  const [showDates, setShowDates] = useState(Boolean(from || to))

  const hasDates = Boolean(from || to)
  const change = (next: { from?: string; to?: string }) => onDateRangeChange?.(next.from, next.to)

  return (
    <div className="flex flex-wrap items-center gap-2 shrink-0">
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
