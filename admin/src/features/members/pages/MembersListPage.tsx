import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import PeopleTable, { peopleCells, type PeopleColumn } from '@/components/PeopleTable'
import PaginationFooter from '@/components/PaginationFooter'
import ListToolbar from '@/components/ListToolbar'
import { allTime, isAllTime, type Range } from '@/features/dashboard/lib/dateRange'
import { useFitRowHeight } from '@/hooks/useFitRows'
import { useMembersList, LIST_PAGE_SIZE } from '@/lib/listHooks'
import { useResetPageOnChange } from '@/lib/pagedTable'
import type { Profile } from '@/types'

export default function MembersListPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [page, setPage] = useState(1)
  const [search, setSearch] = useState('')
  // The join-date window, opened on the whole dataset. It was `from`/`to` pairs
  // before, undefined meaning "no filter"; a `Range` cannot express that, so
  // `isAllTime` stands in for it and the hook is given no bounds at all on that
  // range - which is what keeps this landing render identical to the one before
  // the picker existed.
  const [range, setRange] = useState<Range>(() => allTime())
  const [deleteTarget, setDeleteTarget] = useState<Profile | null>(null)
  const [deleting, setDeleting] = useState(false)

  // Any change to the filters resets to page 1; staying on page 6 of a result
  // set that now has one page renders an empty table.
  useResetPageOnChange(setPage, search, range.start, range.end)

  const all = isAllTime(range)
  const { rows, total, pageCount, isLoading } = useMembersList({
    page, pageSize: LIST_PAGE_SIZE, search,
    from: all ? undefined : range.start,
    to: all ? undefined : range.end,
  })
  // Fifteen rows is the contract; the height of one of them is what gives. The
  // scroller is owned by PeopleTable, so that is what has to be measured.
  const [scrollRef, rowHeight] = useFitRowHeight<HTMLDivElement>({ count: LIST_PAGE_SIZE })

  const columns: PeopleColumn<Profile>[] = [
    { key: 'name', header: 'Name', render: m => <span className="font-medium text-fg-strong">{m.full_name}</span> },
    { key: 'code', header: 'Code', render: m => peopleCells.code(m.code) },
    { key: 'email', header: 'Email', render: m => m.email },
    { key: 'phone', header: 'Phone', render: m => m.phone || '—' },
    { key: 'joined', header: 'Joined', render: m => peopleCells.date(m.created_at) },
    {
      key: 'actions',
      header: 'Actions',
      align: 'right',
      render: m => peopleCells.deleteButton('Delete member', () => setDeleteTarget(m)),
    },
  ]

  const handleDelete = async () => {
    if (!deleteTarget) return
    setDeleting(true)
    try {
      const res = await fetch('/api/delete-user', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: deleteTarget.id }),
      })
      if (!res.ok) {
        const err = await res.json()
        throw new Error(err.error || 'Failed to delete user')
      }
      setDeleteTarget(null)
      queryClient.invalidateQueries({ queryKey: ['profiles'] })
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to delete')
    } finally {
      setDeleting(false)
    }
  }

  return (
    <div className="h-full min-h-0 flex flex-col gap-3">
      {/* Only the date filter lives out here now, right-aligned. The search
          moved into the card header, beside the title, which is where the QR
          queue and every dashboard tab keep theirs. */}
      <ListToolbar range={range} onRangeChange={setRange} />

      <PeopleTable
        title="Members"
        rows={rows}
        columns={columns}
        rowKey={m => m.id}
        onRowClick={m => navigate(`/members/${m.id}`)}
        isLoading={isLoading}
        emptyMessage="No members match these filters"
        scrollRef={scrollRef}
        rowHeight={rowHeight}
        search={{ value: search, onChange: setSearch, placeholder: 'Search by name, code or email…' }}
        startIndex={(page - 1) * LIST_PAGE_SIZE + 1}
        footer={
          <PaginationFooter
            page={page}
            pageCount={pageCount}
            total={total}
            pageSize={LIST_PAGE_SIZE}
            onPageChange={setPage}
          />
        }
      />

      {deleteTarget && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setDeleteTarget(null)}>
          <div className="glass-card rounded-xl max-w-sm w-full mx-4 p-6" onClick={e => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-fg-strong mb-2">Delete Member?</h2>
            <p className="text-sm text-fg mb-4">
              This will permanently delete <strong className="text-fg-strong">{deleteTarget.full_name}</strong>'s account and all access. They will not be able to log in again.
            </p>
            <div className="flex justify-end gap-3">
              <button onClick={() => setDeleteTarget(null)} className="px-4 py-2 text-sm border border-line rounded-lg text-fg hover:bg-overlay-8 cursor-pointer">Cancel</button>
              <button onClick={handleDelete} disabled={deleting}
                className="px-4 py-2 text-sm bg-[#EF4444] text-white rounded-lg hover:bg-[#DC2626] disabled:opacity-50 cursor-pointer">
                {deleting ? 'Deleting...' : 'Delete'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

