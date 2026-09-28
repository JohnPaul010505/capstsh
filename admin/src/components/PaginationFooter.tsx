import { ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight } from 'lucide-react'

/**
 * Numbered pagination footer: « ‹ 1 2 3 … 66 › »
 *
 * The window is centred on the current page and always includes the first and
 * last page, so the total is legible without scrolling a long strip. With 66
 * pages of members, rendering every button is 66 focus stops before the reader
 * gets past the middle of the list.
 */
export interface PaginationFooterProps {
  page: number
  pageCount: number
  total?: number
  pageSize?: number
  onPageChange: (page: number) => void
  /** Labels the record range, e.g. "1–20 of 987". */
  showRange?: boolean
  disabled?: boolean
}

/** Pages to show around the current one, before the ellipsis logic trims them. */
const WINDOW = 2

function buildPages(page: number, pageCount: number): (number | 'gap')[] {
  if (pageCount <= 7) return Array.from({ length: pageCount }, (_, i) => i + 1)
  const out: (number | 'gap')[] = [1]
  const start = Math.max(2, page - WINDOW)
  const end = Math.min(pageCount - 1, page + WINDOW)
  if (start > 2) out.push('gap')
  for (let p = start; p <= end; p++) out.push(p)
  if (end < pageCount - 1) out.push('gap')
  out.push(pageCount)
  return out
}

export default function PaginationFooter({
  page, pageCount, total, pageSize, onPageChange, showRange = true, disabled = false,
}: PaginationFooterProps) {
  const pages = buildPages(page, pageCount)

  const btn = (label: string, target: number, icon?: React.ReactNode, ariaLabel?: string) => {
    const off = disabled || target < 1 || target > pageCount
    return (
      <button
        type="button"
        onClick={() => onPageChange(target)}
        disabled={off}
        aria-label={ariaLabel}
        aria-current={target === page ? 'page' : undefined}
        className={`p-1.5 rounded-lg glass-chip transition-colors ${
          off ? 'opacity-40 cursor-not-allowed' : 'hover:border-[#7C3AED]/50 cursor-pointer'
        }`}
      >
        {icon ?? label}
      </button>
    )
  }

  return (
    <div className="flex items-center justify-between gap-3 px-4 py-2.5 shrink-0 border-t border-line-soft">
      {showRange ? (
        <span className="text-[12px] text-fg-muted tabular-nums">
          {total === undefined
            ? `Page ${page} of ${pageCount}`
            : total === 0
              ? 'No records'
              : pageSize
                ? `${(page - 1) * pageSize + 1}–${Math.min(total, page * pageSize)} of ${total.toLocaleString()}`
                : `Page ${page} of ${pageCount}`}
        </span>
      ) : <span />}

      <nav className="flex items-center gap-1" aria-label="Pagination">
        {btn('', 1, <ChevronsLeft className="w-4 h-4" />, 'First page')}
        {btn('', page - 1, <ChevronLeft className="w-4 h-4" />, 'Previous page')}
        {pages.map((p, i) =>
          p === 'gap' ? (
            <span key={`gap-${i}`} className="px-1.5 text-[12px] text-fg-faint select-none">…</span>
          ) : (
            <button
              key={p}
              type="button"
              onClick={() => onPageChange(p)}
              disabled={disabled}
              aria-current={p === page ? 'page' : undefined}
              aria-label={`Page ${p}`}
              className={`min-w-[2rem] h-8 px-2 rounded-lg text-[13px] tabular-nums transition-colors cursor-pointer ${
                p === page
                  ? 'bg-[#7C3AED] text-white'
                  : 'glass-chip text-fg hover:border-[#7C3AED]/50'
              }`}
            >
              {p}
            </button>
          ),
        )}
        {btn('', page + 1, <ChevronRight className="w-4 h-4" />, 'Next page')}
        {btn('', pageCount, <ChevronsRight className="w-4 h-4" />, 'Last page')}
      </nav>

      <span className="text-[12px] text-fg-muted tabular-nums w-[7rem] text-right">
        Page {page} / {pageCount}
      </span>
    </div>
  )
}
