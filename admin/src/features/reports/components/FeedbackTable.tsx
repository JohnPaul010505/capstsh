import { useState } from 'react'
import { MessageSquare } from 'lucide-react'
import RecordsTable, { type RecordsColumn } from '@/components/RecordsTable'

interface FeedbackRow {
  id: string
  trainer_id: string
  member_id: string
  content: string
  rating?: number | null
  rated_at?: string | null
  /**
   * The member's own reply to this feedback, added in migration 0038. Rendered
   * only in the detail drawer: the list row is one measured 45px line, and a
   * second line of prose in it would break the row-height contract the whole
   * table is built on.
   */
  member_comment?: string | null
  member_commented_at?: string | null
  created_at: string
  // `code` and `email` are joined but only read by the drawer; the list cell
  // still shows the name alone.
  member?: { full_name: string; code?: string | null; email?: string | null }
  trainer?: { full_name: string }
  profiles?: { full_name: string }
}

interface FeedbackTableProps {
  data: FeedbackRow[]
  isLoading: boolean
  /** Opens the detail drawer for a row. Optional: absent, rows are inert. */
  onRowClick?: (row: FeedbackRow) => void
}

export type { FeedbackRow }

/**
 * Recent feedback as the same paged, searchable list as every other list page.
 *
 * It was a plain `<table>` inside a `max-h-[420px]` scroller with an "N entries"
 * count in its header: one fixed page, no numbers, no search, and no way to tell
 * where you were in 50 rows. It now renders through `RecordsTable`, which is what
 * the QR Pending queue uses - a `#` column, an in-card search, a sticky header and
 * a `Showing 1-N of 50 records` footer over a page size measured from the space
 * the table actually has.
 *
 * Two consequences worth knowing:
 *   - `RecordsTable` truncates every cell at 22rem so its rows stay one measured
 *     44px line. A coach's note is longer than that, so the text span carries the
 *     full note as its `title` and the whole thing is still readable on hover.
 *   - The header's "N entries" count is gone because the footer now states the
 *     range and the total, which is a more useful sentence.
 */
export function FeedbackTable({ data, isLoading, onRowClick }: FeedbackTableProps) {
  // Search state lives here, not in the page, so the two pages that mount this
  // component (Coach Feedback, and the unused ReportsAttendancePage) neither has
  // to own it.
  const [search, setSearch] = useState('')

  const memberName = (f: FeedbackRow) => f.member?.full_name ?? f.profiles?.full_name ?? 'Unknown'

  const columns: RecordsColumn<FeedbackRow>[] = [
    {
      key: 'member',
      header: 'Member',
      render: f => <span className="font-medium text-fg-strong">{memberName(f)}</span>,
    },
    {
      key: 'trainer',
      header: 'Trainer',
      render: f => <span className="text-fg">{f.trainer?.full_name ?? '—'}</span>,
    },
    {
      key: 'feedback',
      header: 'Feedback',
      render: f => (
        // `flex`, not `inline-flex`: an inline-level box sits on the text baseline
        // and takes the strut's descender with it, which is another way for a
        // single-line cell to end up 2px over the 44px row budget.
        <span className="flex items-center gap-2 leading-5">
          <MessageSquare className="w-3.5 h-3.5 text-fg-muted shrink-0" />
          <span title={f.content}>{f.content}</span>
        </span>
      ),
    },
    {
      key: 'rating',
      header: 'Rating',
      // A rating of 0 prints "0/5" rather than "Not rated": the average at the top
      // of the page counts any non-null rating, and a row that hid its own 0 while
      // the average included it made the two disagree.
      //
      // `leading-5` is load-bearing. The star glyph's own line box is 22px, so
      // without it this cell rendered 46px rows against `RecordsTable`'s 44px
      // budget: 16 rows were measured as fitting and 15.7 actually did, and the
      // body scrolled by exactly the difference. A measured page size is only
      // honest if every cell is the height the measurement assumes.
      render: f => f.rating == null
        ? <span className="text-fg-faint leading-5">Not rated</span>
        : (
          <span className="inline-flex items-center gap-1 whitespace-nowrap leading-5">
            <span className="text-[#FFC107] leading-5">
              {'★'.repeat(f.rating)}
              <span className="text-fg-faint">{'★'.repeat(5 - f.rating)}</span>
            </span>
            <span className="text-fg-muted">{f.rating}/5</span>
          </span>
        ),
    },
    {
      key: 'date',
      header: 'Date',
      align: 'right',
      render: f => <span className="whitespace-nowrap">{new Date(f.created_at).toLocaleDateString()}</span>,
    },
  ]

  return (
    <RecordsTable
      title="Recent Feedback"
      columns={columns}
      rows={data}
      rowKey={f => f.id}
      searchFields={f => [memberName(f), f.trainer?.full_name, f.content]}
      searchPlaceholder="Search by member, trainer or feedback…"
      searchValue={search}
      onSearchChange={setSearch}
      isLoading={isLoading}
      onRowClick={onRowClick}
      emptyMessage={data.length === 0 ? 'No feedback recorded yet' : 'No feedback matches this search'}
    />
  )
}
