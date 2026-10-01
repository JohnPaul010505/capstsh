import { useMemo, useState, type ReactNode } from 'react'
import { ChevronLeft, ChevronRight, Inbox, Search } from 'lucide-react'
import { useFitRows } from '@/hooks/useFitRows'

export interface RecordsColumn<T> {
  key: string
  header: string
  className?: string
  /**
   * Horizontal alignment of the header and its cells. Row cells wrap their
   * content in a `max-w-[22rem] truncate` block, so an action column whose
   * buttons should sit against the right edge needs this: a right-aligned
   * flex row inside a left-aligned block still starts at the left.
   */
  align?: 'left' | 'right'
  render: (row: T, index: number) => ReactNode
}

interface RecordsTableProps<T> {
  title: string
  columns: RecordsColumn<T>[]
  rows: T[]
  rowKey: (row: T) => string
  searchFields: (row: T) => (string | null | undefined)[]
  searchPlaceholder: string
  searchValue: string
  onSearchChange: (value: string) => void
  isLoading?: boolean
  emptyMessage?: string
  /**
   * One line under the title. Optional and additive: the Predictions page
   * carries a sentence there explaining what the `basis` column is and that
   * re-generating replaces a row rather than duplicating it, which was worth
   * keeping and had nowhere to go once its bespoke header came off.
   */
  subtitle?: string
  /**
   * Pins the page size instead of measuring it. Leave unset: the table has to
   * fit its container by construction, because a hardcoded page size either
   * leaves a gap on a tall window or overflows on a short one - and the overflow
   * was invisible, because the container clipped it and the row that landed on
   * the boundary rendered sliced in half with no scrollbar to explain it.
   */
  pageSize?: number
}

/** One row is `py-3` around `text-sm`/`text-[12px]` content plus a 1px rule. */
const ROW_HEIGHT = 44
/** The sticky header row: `py-2.5` around `text-[12px]`, plus its bottom rule. */
const HEADER_HEIGHT = 40

/**
 * Shared records table for the dashboard tabs: title + search in the header, a
 * glass card around a plain table with a `#` index column, client-side search
 * and pagination, and loading/empty states.
 *
 * The page size is MEASURED from the space the table actually has (see
 * useFitRows), so a full page is always a whole page. Two earlier versions got
 * this wrong in opposite directions: a fixed `pageSize={10}` overflowed a ~215px
 * body and clipped rows mid-height, and a `flex-1` chart beside it left the
 * table about three rows tall in the first place.
 */
export default function RecordsTable<T>({
  title, columns, rows, rowKey, searchFields, searchPlaceholder,
  searchValue, onSearchChange, isLoading, emptyMessage, subtitle, pageSize: pageSizeProp,
}: RecordsTableProps<T>) {

  const [page, setPage] = useState(0)
  // The ref belongs on the scroll container - that element's height is the budget.
  const [scrollRef, measuredPageSize] = useFitRows<HTMLDivElement>({
    reserve: HEADER_HEIGHT,
    rowHeight: ROW_HEIGHT,
    min: 2,
    max: 100,
    fallback: 8,
  })
  const pageSize = pageSizeProp ?? measuredPageSize

  // When the page size is PINNED, the body is capped at exactly that many rows
  // rather than stretching to fill the card. Without the cap a tall window left
  // a large empty area under 10 rows, because the card is a flex child that
  // grows to whatever height the panel hands it. The cap also means the body
  // scrolls internally whenever the rows do not fit the space left over, which
  // is what keeps the panel from pushing the page past the viewport.
  const pinnedBodyHeight = pageSizeProp ? HEADER_HEIGHT + pageSizeProp * ROW_HEIGHT : undefined

  const filtered = useMemo(() => {
    const q = searchValue.trim().toLowerCase()
    if (!q) return rows
    return rows.filter(row => searchFields(row).some(v => (v ?? '').toLowerCase().includes(q)))
  }, [rows, searchValue, searchFields])

  const pageCount = Math.max(1, Math.ceil(filtered.length / pageSize))
  const safePage = Math.min(page, pageCount - 1)
  const from = filtered.length === 0 ? 0 : safePage * pageSize + 1
  const to = Math.min(filtered.length, safePage * pageSize + pageSize)
  const pageRows = filtered.slice(safePage * pageSize, safePage * pageSize + pageSize)

  const goto = (p: number) => setPage(Math.max(0, Math.min(pageCount - 1, p)))

  return (
    // `flex-1 min-h-0` lets the table absorb whatever height the header, KPIs
    // and chart above it did not use, and scroll internally instead of pushing
    // the page past the viewport. The floor stops it collapsing on a short
    // window, where the table would otherwise vanish entirely.
    // The floor is deliberately small (8rem). It only has to keep the table
    // from collapsing on a very short window; the real height is what the flex
    // parent hands it, and a large floor here is what made the whole panel
    // overflow a 768px viewport.
    <section className="glass-panel rounded-2xl flex flex-col flex-1 min-h-[6rem]" aria-label={title}>
      <div className="flex flex-wrap items-center justify-between gap-2 px-4 pt-3.5 pb-3 shrink-0">
        <div className="min-w-0">
          <h3 className="text-[15px] font-semibold text-fg-strong">{title}</h3>
          {subtitle && <p className="mt-0.5 text-[12px] text-fg-muted leading-4">{subtitle}</p>}
        </div>
        <div className="relative w-full sm:w-80">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-fg-faint pointer-events-none" />
          <input
            type="search"
            value={searchValue}
            onChange={e => { onSearchChange(e.target.value); setPage(0) }}
            placeholder={searchPlaceholder}
            aria-label={`Search ${title}`}
            className="w-full pl-9 pr-3 py-2 glass-input rounded-xl text-sm text-fg-strong placeholder:text-fg-faint focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50"
          />
        </div>
      </div>
      <div className="px-4 pb-3 flex-1 min-h-0 flex flex-col gap-2.5">
        {/*
          ONE scroll container. This used to nest `overflow-auto` around
          `overflow-x-auto` around the table, which produced a scrollbar nobody
          could see and a body whose real height had nothing to do with the
          space the page had left. `min-h-0` is what lets the flex child shrink
          below its content instead of forcing the card to grow.
        */}
        <div
          ref={scrollRef}
          style={pinnedBodyHeight ? { maxHeight: pinnedBodyHeight } : undefined}
          className="rounded-xl border border-line-soft overflow-auto flex-1 min-h-0 [scrollbar-width:thin] [scrollbar-color:var(--overlay-10)_transparent] [&::-webkit-scrollbar]:h-8 [&::-webkit-scrollbar]:w-2 [&::-webkit-scrollbar-track]:bg-transparent [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-[var(--overlay-10)] [&::-webkit-scrollbar-thumb:hover]:bg-[#7C3AED]/60"
        >
          <table className="w-full min-w-max">
            <thead className="sticky top-0 z-10">
              <tr className="border-b border-line bg-[var(--table-head-bg)] shadow-[0_1px_0_var(--line),0_6px_12px_-8px_rgba(0,0,0,0.55)]">
                <th scope="col" className="text-left px-4 py-2.5 text-[12px] font-semibold text-fg-muted">#</th>
                {columns.map(c => (
                  <th key={c.key} scope="col" className={`${c.align === 'right' ? 'text-right' : 'text-left'} px-4 py-2.5 text-[12px] font-semibold text-fg-muted ${c.className ?? ''}`}>{c.header}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr>
                  <td colSpan={columns.length + 1} className="px-4 py-8 text-center text-sm text-fg-muted">Loading…</td>
                </tr>
              ) : pageRows.length === 0 ? (
                <tr>
                  <td colSpan={columns.length + 1} className="px-4 py-10 text-center">
                    <span className="inline-flex items-center justify-center w-10 h-10 rounded-full bg-overlay-8 text-fg-faint">
                      <Inbox className="w-5 h-5" strokeWidth={1.75} />
                    </span>
                    <p className="mt-2 text-sm text-fg-faint">{emptyMessage ?? 'No records found'}</p>
                  </td>
                </tr>
              ) : (
                pageRows.map((row, i) => (
                  <tr key={rowKey(row)} className="border-b border-line-soft last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                    <td className="px-4 py-3 text-sm text-fg-muted tabular-nums">{safePage * pageSize + i + 1}</td>
                    {columns.map(c => (
                      <td
                        key={c.key}
                        className={`px-4 py-3 text-sm text-fg align-middle ${c.align === 'right' ? 'text-right' : ''} ${c.className ?? ''}`}
                      >
                        <div className="max-w-[22rem] truncate">{c.render(row, safePage * pageSize + i)}</div>
                      </td>
                    ))}
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
        {/*
          Always rendered, including while loading. It used to disappear
          whenever the result set fitted on one page, which changed the
          container's height, which re-fired the measurement that picks the page
          size - the table oscillated between two row counts. A fixed footer
          keeps the height stable and keeps the "of N" count honest at all times.
        */}
        <div className="flex items-center justify-between gap-3 text-[12px] text-fg-muted shrink-0">
          <span className="tabular-nums">
            {isLoading
              ? 'Loading records…'
              : filtered.length === 0
                ? 'No records'
                : `Showing ${from.toLocaleString()}–${to.toLocaleString()} of ${filtered.length.toLocaleString()} records`}
          </span>
          <div className="flex items-center gap-1">
            <button
              type="button"
              onClick={() => goto(safePage - 1)}
              disabled={safePage === 0 || isLoading}
              aria-label="Previous page"
              className="p-1.5 rounded-lg bg-[#7C3AED] text-white cursor-pointer transition-colors hover:bg-[#6D28D9] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#7C3AED]/60 disabled:bg-[var(--overlay-8)] disabled:text-fg-faint disabled:opacity-100 disabled:cursor-not-allowed"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>
            <span className="px-2 tabular-nums">{safePage + 1} / {pageCount}</span>
            <button
              type="button"
              onClick={() => goto(safePage + 1)}
              disabled={safePage >= pageCount - 1 || isLoading}
              aria-label="Next page"
              className="p-1.5 rounded-lg bg-[#7C3AED] text-white cursor-pointer transition-colors hover:bg-[#6D28D9] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#7C3AED]/60 disabled:bg-[var(--overlay-8)] disabled:text-fg-faint disabled:opacity-100 disabled:cursor-not-allowed"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </section>
  )
}
