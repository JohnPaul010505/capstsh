import { Trash2 } from 'lucide-react'
import { cn } from '@/lib/utils'

/**
 * The members and trainers tables, as one component.
 *
 * The plan requires the two pages to look and behave identically; the previous
 * code had two separate tables (MemberTable, and an inline one in
 * TrainersListPage) that had already drifted. Columns are declared by the
 * caller so the shared markup stays shared without forcing an identical set of
 * fields on two different entities.
 */
export interface PeopleColumn<T> {
  key: string
  header: string
  /** Right-aligned headers and cells (e.g. an actions column). */
  align?: 'left' | 'right'
  className?: string
  render: (row: T) => React.ReactNode
}

export interface PeopleTableProps<T> {
  rows: T[]
  columns: PeopleColumn<T>[]
  rowKey: (row: T) => string
  onRowClick?: (row: T) => void
  isLoading?: boolean
  emptyMessage?: string
  /** Extra node in the header row, right-aligned (e.g. a "New trainer" button). */
  headerExtra?: React.ReactNode
  /** Adds vertical padding for a roomier density. */
  dense?: boolean
  /**
   * Ref for the scrolling body, so `useFitRows` can measure the height budget
   * and the page can size itself to it. Measured here rather than on the page
   * because this component owns the scroller — measuring the page would include
   * the toolbar and footer and over-count the rows that fit.
   */
  scrollRef?: React.RefObject<HTMLDivElement | null>
}

export default function PeopleTable<T>({
  rows, columns, rowKey, onRowClick, isLoading, emptyMessage,
  headerExtra, dense = false, scrollRef,
}: PeopleTableProps<T>) {
  // Row click is optional: when no handler is given the default route depends
  // on the entity, so the caller supplies it (people rows go to /members or
  // /trainers by id).
  const go = onRowClick ?? (() => {})

  const cellPad = dense ? 'px-4 py-2' : 'px-4 py-3'

  return (
    <div className="glass-card rounded-xl overflow-hidden flex flex-col flex-1 min-h-0">
      <div className="flex items-center justify-between gap-3 px-4 py-3 border-b border-line shrink-0">
        <span className="text-sm font-medium text-fg-muted">
          {isLoading ? 'Loading…' : `${rows.length.toLocaleString()} on this page`}
        </span>
        {headerExtra}
      </div>

      <div className="flex-1 min-h-0 overflow-auto" ref={scrollRef as React.Ref<HTMLDivElement>}>
        <table className="w-full">
          <thead className="sticky top-0 z-10">
            <tr className="border-b border-line bg-overlay-5">
              {columns.map(c => (
                <th
                  key={c.key}
                  className={cn(
                    'text-sm font-medium text-fg-muted',
                    cellPad,
                    c.align === 'right' ? 'text-right' : 'text-left',
                    c.className,
                  )}
                >
                  {c.header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              <tr>
                <td colSpan={columns.length} className="px-4 py-8 text-center text-fg-muted">Loading…</td>
              </tr>
            ) : rows.length === 0 ? (
              <tr>
                <td colSpan={columns.length} className="px-4 py-10 text-center text-fg-muted">
                  {emptyMessage ?? 'Nothing to show'}
                </td>
              </tr>
            ) : (
              rows.map(row => (
                <tr
                  key={rowKey(row)}
                  onClick={() => go(row)}
                  className={cn(
                    'border-b border-line-soft last:border-0 transition-colors',
                    onRowClick && 'cursor-pointer hover:bg-[#7C3AED]/5',
                  )}
                >
                  {columns.map(c => (
                    <td
                      key={c.key}
                      className={cn('text-sm text-fg', cellPad, c.align === 'right' ? 'text-right' : 'text-left', c.className)}
                    >
                      {c.render(row)}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}

/** Common cell renderers, so a field looks the same on both pages. */
export const peopleCells = {
  code: (code: string | null) => (
    <span className="font-mono font-medium text-[#7C3AED]">{code ?? '—'}</span>
  ),
  date: (iso: string | null | undefined) => (
    <span>{iso ? new Date(iso).toLocaleDateString() : '—'}</span>
  ),
  deleteButton: (label: string, onClick: () => void) => (
    <button
      type="button"
      onClick={e => { e.stopPropagation(); onClick() }}
      title={label}
      aria-label={label}
      className="p-1 text-fg-muted hover:text-[#EF4444] cursor-pointer"
    >
      <Trash2 className="w-4 h-4" />
    </button>
  ),
}
