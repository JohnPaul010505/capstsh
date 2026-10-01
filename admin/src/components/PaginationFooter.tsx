import { ChevronLeft, ChevronRight } from 'lucide-react'

/**
 * This WAS a numbered pager: « ‹ 1 2 3 … 66 › »
 *
 * It also carried a matching "Page 1 / 66" label on the far right, and that
 * strip was the last thing still making the members, trainers and memberships
 * pages read as a different app from the QR queue and every dashboard tab, all
 * of which end on `RecordsTable`'s compact footer. This now renders that same
 * row: `Showing 1-15 of 987 records` on the left, `1 / 66` between two arrows
 * on the right (en dash on the range, exactly as `RecordsTable` writes it).
 *
 * The numbered window was not lost so much as it was redundant. The labels
 * either side of it already said where the reader was, and 66 focus stops
 * before the middle of a list is a lot to ask of someone who only wants the
 * next twenty rows.
 */
export interface PaginationFooterProps {
  page: number
  pageCount: number
  total?: number
  pageSize?: number
  onPageChange: (page: number) => void
  /** Labels the record range, e.g. "Showing 1-20 of 987 records". */
  showRange?: boolean
  disabled?: boolean
}

export default function PaginationFooter({
  page, pageCount, total, pageSize, onPageChange, showRange = true, disabled = false,
}: PaginationFooterProps) {
  // The range and the arrows describe the SAME page, so they are computed from
  // the same three numbers. `total` is optional because the renewal queue
  // renders it from an in-memory slice rather than a server count.
  const range =
    total === undefined
      ? `Page ${page} of ${pageCount}`
      : total === 0
        ? 'No records'
        : `Showing ${((page - 1) * (pageSize ?? total) + 1).toLocaleString()}–${Math.min(total, page * (pageSize ?? total)).toLocaleString()} of ${total.toLocaleString()} records`

  const navBtn = (target: number, icon: React.ReactNode, ariaLabel: string) => {
    const off = disabled || target < 1 || target > pageCount
    return (
      <button
        type="button"
        onClick={() => onPageChange(target)}
        disabled={off}
        aria-label={ariaLabel}
        className={`p-1.5 rounded-lg bg-[#7C3AED] text-white cursor-pointer transition-colors hover:bg-[#6D28D9] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#7C3AED]/60 disabled:bg-[var(--overlay-8)] disabled:text-fg-faint disabled:opacity-100 disabled:cursor-not-allowed`}
      >
        {icon}
      </button>
    )
  }

  return (
    // The same footer row `RecordsTable` renders - range left, arrows and
    // "n / m" right - so a reader who has learned one list has learned all of
    // them. The only case it does not have is the loading one: these lists get
    // their rows from PostgREST with the previous page still on screen, and
    // swapping the range for "Loading records..." would make the footer jump
    // on every keystroke of the search box.
    <div className="flex items-center justify-between gap-3 text-[12px] text-fg-muted shrink-0">
      {showRange ? <span className="tabular-nums">{range}</span> : <span />}
      <div className="flex items-center gap-1">
        {navBtn(page - 1, <ChevronLeft className="w-4 h-4" />, 'Previous page')}
        <span className="px-2 tabular-nums">{page} / {pageCount}</span>
        {navBtn(page + 1, <ChevronRight className="w-4 h-4" />, 'Next page')}
      </div>
    </div>
  )
}
