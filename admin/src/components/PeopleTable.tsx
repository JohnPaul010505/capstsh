import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { Search, Trash2 } from 'lucide-react'
import { cn } from '@/lib/utils'

/**
 * The members, trainers and memberships tables, as one component.
 *
 * The plan requires the list pages to look and behave identically; the previous
 * code had three separate tables (MemberTable, an inline one in
 * TrainersListPage, and another inline one in MembershipsPage) that had already
 * drifted. Columns are declared by the caller so the shared markup stays shared
 * without forcing an identical set of fields on three different entities.
 */
export interface PeopleColumn<T> {
  key: string
  header: string
  /** Right-aligned headers and cells (e.g. an actions column). */
  align?: 'left' | 'right'
  className?: string
  render: (row: T) => React.ReactNode
}

/** Cell padding when nothing has been measured yet: the roomy default. */
const DEFAULT_PAD_Y = 12
/**
 * Zero is allowed. At the bottom of the range the row height and the content
 * inside it are within a pixel of each other, and a 1px floor here costs a whole
 * extra pixel per row - which at fifteen rows is a scrollbar. The row's own
 * 1px rule still separates the rows.
 */
const MIN_PAD_Y = 0

export interface PeopleTableProps<T> {
  rows: T[]
  columns: PeopleColumn<T>[]
  rowKey: (row: T) => string
  onRowClick?: (row: T) => void
  isLoading?: boolean
  emptyMessage?: string
  /** Extra node in the header row, right-aligned (e.g. a total count). */
  headerExtra?: React.ReactNode
  /**
   * Heading in the card's own header strip.
   *
   * Passing this switches the header from the old "15 on this page" counter to
   * the QR queue's layout: title on the left, search on the right. That is what
   * makes these three pages read as the same page as every `RecordsTable` in
   * the app rather than a second, older kind of list.
   */
  title?: string
  /**
   * The search box for that header, controlled by the caller because the query
   * itself lives in the page (these lists are filtered server-side, so the term
   * has to reach PostgREST rather than be matched in the browser).
   */
  search?: {
    value: string
    onChange: (value: string) => void
    placeholder: string
    /** Quiet period before `onChange` fires. Defaults to ListToolbar's 300ms. */
    debounceMs?: number
  }
  /**
   * Row number of the first row on screen, so the `#` column counts through the
   * whole result set instead of restarting at 1 on every page. Pass
   * `(page - 1) * pageSize + 1`.
   */
  startIndex?: number
  /** Rendered under the table inside the card - the list pages' pager. */
  footer?: React.ReactNode
  /**
   * Height of ONE body row, from `useFitRowHeight({ count: pageSize })`.
   *
   * Pass it together with the page size the list actually requested. The two
   * are a pair: 15 rows at the measured height fill the card exactly, which is
   * what makes a full page a whole page with no inner scrollbar. Omit it and
   * rows render at their natural, roomy height.
   */
  rowHeight?: number
  /**
   * Ref for the scrolling body, so `useFitRowHeight` can measure the height
   * budget. Measured here rather than on the page because this component owns
   * the scroller - measuring the page would include the toolbar and footer and
   * under-count the rows that fit.
   */
  scrollRef?: React.RefObject<HTMLDivElement | null>
}

/**
 * The search box that lives in the card header, matching `RecordsTable`'s.
 *
 * It is DEBOUNCED here, where it used to live in `ListToolbar`, and the reason
 * has not changed: these lists are queried from PostgREST, so every keystroke
 * is a round trip, and on a 987-row table the last response to arrive is not
 * necessarily the last one sent. The input stays controlled by the local draft
 * so typing never feels laggy while the outward value catches up 300ms later.
 */
function CardSearch({ value, onChange, placeholder, debounceMs = 300 }: {
  value: string
  onChange: (value: string) => void
  placeholder: string
  debounceMs?: number
}) {
  const [draft, setDraft] = useState(value)
  // The last value actually SENT, which is not the same as the last value
  // received: during the quiet period the parent still holds the old term.
  const sent = useRef(value)

  useEffect(() => {
    if (draft === value) return
    const id = window.setTimeout(() => { sent.current = draft; onChange(draft) }, debounceMs)
    return () => window.clearTimeout(id)
  }, [draft, value, onChange, debounceMs])

  // Adopt an external clear (from anywhere else on the page) without wiping
  // the word the reader is halfway through. Comparing to what was SENT rather
  // than to '' directly is what stops the box clearing itself after the first
  // character, while `value` is still the pre-debounce empty string.
  useEffect(() => {
    if (sent.current !== value) {
      sent.current = value
      if (value === '' && draft !== '') setDraft('')
    }
  }, [value, draft])

  return (
    <div className="relative w-full sm:w-80">
      <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-fg-faint pointer-events-none" />
      <input
        type="search"
        value={draft}
        onChange={e => setDraft(e.target.value)}
        placeholder={placeholder}
        aria-label={placeholder}
        className="w-full pl-9 pr-3 py-2 glass-input rounded-xl text-sm text-fg-strong placeholder:text-fg-faint focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50"
      />
    </div>
  )
}

export default function PeopleTable<T>({
  rows, columns, rowKey, onRowClick, isLoading, emptyMessage,
  headerExtra, rowHeight, scrollRef, title, search, startIndex = 1, footer,
}: PeopleTableProps<T>) {
  // Row click is optional: when no handler is given the default route depends
  // on the entity, so the caller supplies it (people rows go to /members or
  // /trainers by id; membership rows have no detail page and get no handler).
  const go = onRowClick ?? (() => {})

  /**
   * Vertical padding, derived from the row height and the row's own content.
   *
   * A table row's `height` is a MINIMUM, never a maximum: `height: 41px` on a
   * row whose cells want 12px of padding and a 20px line box renders at 45px,
   * and the card grows a scrollbar again. Which is why a fixed padding ladder
   * (py-3 / py-2 / py-1.5) is not enough here - it assumes every row holds a
   * single line of text, while a trainer row holds a 28px avatar and a renewal
   * row holds a 28px action button.
   *
   * So the padding is measured, not guessed: take the tallest thing actually in
   * the first row and give the remainder to padding, split above and below.
   * Every row then occupies exactly the height the page asked for, whatever it
   * contains.
   */
  const bodyRef = useRef<HTMLTableSectionElement>(null)
  const [padY, setPadY] = useState<number | null>(null)

  useLayoutEffect(() => {
    if (!rowHeight) {
      setPadY(null)
      return
    }
    const tr = bodyRef.current?.querySelector('tbody tr')
    if (!tr || !tr.children.length) return
    let tallest = 0
    for (const cell of Array.from(tr.children) as HTMLTableCellElement[]) {
      const inner = cell.firstElementChild as HTMLElement | null
      // A cell that renders bare text has no element to measure, so its line
      // box stands in for it.
      const height = inner
        ? inner.getBoundingClientRect().height
        : parseFloat(getComputedStyle(cell).lineHeight) || 0
      if (height > tallest) tallest = height
    }
    // The row's own rule is part of the row's height. Leaving it out costs one
    // pixel per row, which is fifteen pixels and one scrollbar per page.
    const border = parseFloat(getComputedStyle(tr).borderBottomWidth) || 0
    const next = Math.max(
      MIN_PAD_Y,
      Math.min(DEFAULT_PAD_Y, Math.floor((rowHeight - tallest - border) / 2)),
    )
    setPadY(prev => (prev === next ? prev : next))
  }, [rowHeight, rows, isLoading])

  const cellPad = padY === null
    ? { paddingTop: DEFAULT_PAD_Y, paddingBottom: DEFAULT_PAD_Y }
    : { paddingTop: padY, paddingBottom: padY }
  // The header keeps its own padding: it is the `reserve` the row-height
  // measurement subtracts, so letting it move with the rows would move the
  // measurement and the two would chase each other.
  //
  // `py-2.5 text-[12px]` is `RecordsTable`'s header, and `useFitRowHeight`'s
  // reserve was dropped 46 -> 40 to match it. The two are a pair: overstate the
  // reserve and the rows are measured short, understate it and fifteen rows
  // overflow the card with the container clipping them (no scrollbar, just a
  // row sliced in half). 40 is 10 + 10 + an 18px line box + the 1px rule.
  const headPad = 'px-4 py-2.5'
  const rowStyle = rowHeight ? { height: rowHeight } : undefined
  const bodyCell = 'align-middle text-sm text-fg px-4'

  return (
    // The card is `RecordsTable`'s, not the older one: a `glass-panel` rounded
    // at 2xl, a title/search header, one bordered scroll container, and the
    // pager inside the card where every other list in the app keeps it.
    <section className="glass-panel rounded-2xl flex flex-col flex-1 min-h-0" aria-label={title}>
      <div className="flex flex-wrap items-center justify-between gap-2 px-4 pt-3.5 pb-3 shrink-0">
        {title ? (
          <div className="min-w-0">
            <h3 className="text-[15px] font-semibold text-fg-strong">{title}</h3>
          </div>
        ) : (
          <span className="text-[12px] font-medium text-fg-muted">
            {isLoading ? 'Loading…' : `${rows.length.toLocaleString()} on this page`}
          </span>
        )}
        {search ? (
          <CardSearch
            value={search.value}
            onChange={search.onChange}
            placeholder={search.placeholder}
            debounceMs={search.debounceMs}
          />
        ) : headerExtra}
      </div>

      <div className="px-4 pb-3 flex-1 min-h-0 flex flex-col gap-2.5">
        <div
          ref={scrollRef as React.Ref<HTMLDivElement>}
          className="rounded-xl border border-line-soft overflow-auto flex-1 min-h-0 [scrollbar-width:thin] [scrollbar-color:var(--overlay-10)_transparent] [&::-webkit-scrollbar]:h-8 [&::-webkit-scrollbar]:w-2 [&::-webkit-scrollbar-track]:bg-transparent [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-[var(--overlay-10)] [&::-webkit-scrollbar-thumb:hover]:bg-[#7C3AED]/60"
        >
          <table className="w-full">
            <thead className="sticky top-0 z-10">
              <tr className="border-b border-line bg-[var(--table-head-bg)] shadow-[0_1px_0_var(--line),0_6px_12px_-8px_rgba(0,0,0,0.55)]">
                <th scope="col" className={cn(headPad, 'text-left text-[12px] font-semibold text-fg-muted')}>#</th>
                {columns.map(c => (
                  <th
                    key={c.key}
                    scope="col"
                    className={cn(
                      'text-[12px] font-semibold text-fg-muted',
                      headPad,
                      c.align === 'right' ? 'text-right' : 'text-left',
                      c.className,
                    )}
                  >
                    {c.header}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody ref={bodyRef}>
              {isLoading ? (
                <tr style={rowStyle}>
                  <td colSpan={columns.length + 1} className="px-4 py-8 text-center align-middle text-fg-muted">Loading…</td>
                </tr>
              ) : rows.length === 0 ? (
                <tr style={rowStyle}>
                  <td colSpan={columns.length + 1} className="px-4 py-10 text-center align-middle text-fg-muted">
                    {emptyMessage ?? 'Nothing to show'}
                  </td>
                </tr>
              ) : (
                rows.map((row, i) => (
                  <tr
                    key={rowKey(row)}
                    onClick={() => go(row)}
                    style={rowStyle}
                    className={cn(
                      'border-b border-line-soft last:border-0 transition-colors',
                      onRowClick && 'cursor-pointer hover:bg-[#7C3AED]/5',
                    )}
                  >
                    {/* The `#` column `RecordsTable` leads every list with. Its
                        cell is deliberately bare text: the padding measurement
                        above reads the line box for a text-only cell, and a
                        wrapped span here would change the row's height. */}
                    <td style={cellPad} className="align-middle px-4 text-sm text-fg-muted tabular-nums">
                      {(startIndex ?? 1) + i}
                    </td>
                    {columns.map(c => (
                      <td
                        key={c.key}
                        style={cellPad}
                        className={cn(bodyCell, c.align === 'right' ? 'text-right' : 'text-left', c.className)}
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
        {footer}
      </div>
    </section>
  )
}

/** Common cell renderers, so a field looks the same on every page. */
export const peopleCells = {
  // `undefined` is accepted as well as `null`: these cells are fed straight from
  // a joined row (`m.profiles?.code`), where a missing member is `undefined`
  // rather than `null`. The colour is the name column's own `text-fg-strong`
  // (it used to be purple, which made the ID shout louder than the person).
  code: (code: string | null | undefined) => (
    <span className="font-mono font-medium text-fg-strong">{code ?? '—'}</span>
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
