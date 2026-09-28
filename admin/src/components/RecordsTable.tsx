import { useMemo, useState, type ReactNode } from 'react'
import { ChevronLeft, ChevronRight, Inbox, Search } from 'lucide-react'

export interface RecordsColumn<T> {
  key: string
  header: string
  className?: string
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
  /** Rows per page — caps the DOM so wide ranges never render thousands of rows. */
  pageSize?: number
}

/**
 * Shared records table for the dashboard tabs: title + search in the header,
 * a glass card around a plain table with a `#` index column, client-side
 * search + pagination, and loading/empty states.
 */
export default function RecordsTable<T>({
  title, columns, rows, rowKey, searchFields, searchPlaceholder,
  searchValue, onSearchChange, isLoading, emptyMessage, pageSize = 10,
}: RecordsTableProps<T>) {

  const [page, setPage] = useState(0)

  const filtered = useMemo(() => {
    const q = searchValue.trim().toLowerCase()
    if (!q) return rows
    return rows.filter(row => searchFields(row).some(v => (v ?? '').toLowerCase().includes(q)))
  }, [rows, searchValue, searchFields])

  const pageCount = Math.max(1, Math.ceil(filtered.length / pageSize))
  const safePage = Math.min(page, pageCount - 1)
  const pageRows = filtered.slice(safePage * pageSize, safePage * pageSize + pageSize)

  const goto = (p: number) => setPage(Math.max(0, Math.min(pageCount - 1, p)))

  return (
    // `flex-1 min-h-0` lets the table absorb whatever height the header, KPIs
    // and chart above it did not use, and scroll internally instead of pushing
    // the page past the viewport. The 120px floor stops it collapsing to
    // nothing on a short window, where the table would otherwise vanish.
    <section className="glass-panel rounded-2xl flex flex-col flex-1 min-h-[7.5rem]" aria-label={title}>
      <div className="flex flex-wrap items-center justify-between gap-2 px-4 pt-3.5 pb-3 shrink-0">
        <h3 className="text-[15px] font-semibold text-fg-strong">{title}</h3>
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
        <div className="rounded-xl border border-line-soft overflow-hidden flex-1 min-h-0 overflow-auto">
          <div className="overflow-x-auto">
            <table className="w-full min-w-max">
              <thead>
                <tr className="border-b border-line bg-overlay-5">
                  <th className="text-left px-4 py-2.5 text-[12px] font-semibold text-fg-muted">#</th>
                  {columns.map(c => (
                    <th key={c.key} className={`text-left px-4 py-2.5 text-[12px] font-semibold text-fg-muted ${c.className ?? ''}`}>{c.header}</th>
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
                      <td className="px-4 py-3 text-sm text-fg-muted">{safePage * pageSize + i + 1}</td>
                      {columns.map(c => (
                        <td key={c.key} className={`px-4 py-3 text-sm text-fg ${c.className ?? ''}`}>{c.render(row, safePage * pageSize + i)}</td>
                      ))}
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
        {!isLoading && filtered.length > pageSize && (
          <div className="flex items-center justify-between text-[12px] text-fg-muted shrink-0">
            <span>
              Showing {safePage * pageSize + 1}–{Math.min(filtered.length, safePage * pageSize + pageSize)} of {filtered.length.toLocaleString()} records
            </span>
            <div className="flex items-center gap-1">
              <button
                type="button"
                onClick={() => goto(safePage - 1)}
                disabled={safePage === 0}
                aria-label="Previous page"
                className="p-1.5 rounded-lg glass-chip cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed hover:border-[#7C3AED]/50 transition-colors"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>
              <span className="px-2 tabular-nums">{safePage + 1} / {pageCount}</span>
              <button
                type="button"
                onClick={() => goto(safePage + 1)}
                disabled={safePage >= pageCount - 1}
                aria-label="Next page"
                className="p-1.5 rounded-lg glass-chip cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed hover:border-[#7C3AED]/50 transition-colors"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}
      </div>
    </section>
  )
}
