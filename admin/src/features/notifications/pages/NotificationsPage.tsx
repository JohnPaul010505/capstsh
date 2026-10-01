import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { Send, Users } from 'lucide-react'
import RecordsTable, { type RecordsColumn } from '@/components/RecordsTable'

/**
 * The send form, plus the 50 most recent notifications as a paged list.
 *
 * "Recent Notifications" was a plain `<table>` inside a `max-h-[420px]`
 * scroller: one fixed page, no numbers, no search, and no way to tell which of
 * the 50 rows you were looking at. It now renders through `RecordsTable` -
 * the same component the QR Pending queue and the Reports lists use - so it
 * gets a `#` column, an in-card search, a sticky header and a
 * `Showing 1-N of 50 records` footer over a page size measured from the space
 * the table actually has.
 *
 * The page shell changed with it, from `space-y-3` to
 * `h-full min-h-0 flex flex-col`. That is not cosmetic: `main` is
 * `flex-1 overflow-hidden`, so an auto-height page simply runs off the bottom
 * of the viewport with no scrollbar to say so, and the 420px scroller is what
 * was hiding it. `RecordsTable` measures its own page size from the height its
 * flex parent hands it, so it needs a real height budget to measure against.
 */
export default function NotificationsPage() {
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [targetRole, setTargetRole] = useState<'all' | 'member' | 'trainer'>('all')
  const [sending, setSending] = useState(false)
  // Owned here rather than inside RecordsTable, which is a controlled input: the
  // same term has to survive the re-render that follows a broadcast.
  const [search, setSearch] = useState('')
  const queryClient = useQueryClient()

  const { data: sentNotifications, isLoading } = useQuery({
    queryKey: ['sent-notifications'],
    queryFn: async () => {
      const { data } = await supabase
        .from('notifications')
        .select('*, profiles!notifications_user_id_fkey(full_name)')
        .order('created_at', { ascending: false })
        .limit(50)
      return data ?? []
    },
  })

  const handleSend = async () => {
    if (!title.trim() || !body.trim()) return
    setSending(true)
    try {
      const res = await fetch('/api/notifications/broadcast', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: title.trim(), body: body.trim(), targetRole }),
      })
      if (!res.ok) {
        const err = await res.json().catch(() => ({}))
        throw new Error(err.error || 'Failed to broadcast')
      }
      setTitle('')
      setBody('')
      setTargetRole('all')
      queryClient.invalidateQueries({ queryKey: ['sent-notifications'] })
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to send notifications')
    } finally {
      setSending(false)
    }
  }

  const rows = sentNotifications ?? []

  // `leading-5` on the Body cell is load-bearing, not cosmetic: `RecordsTable`
  // measures its rows at a fixed 44px, and the message body's own line box is
  // taller than `text-sm`'s strut. Without it every row renders 46px, sixteen
  // rows get measured as fitting, and the body scrolls by exactly the
  // difference - a measured page size is only honest if every cell is the
  // height the measurement assumes.
  const columns: RecordsColumn<(typeof rows)[number]>[] = [
    {
      key: 'title',
      header: 'Title',
      // `leading-5` for the reason the Predictions page's basis cell needed
      // `leading-4`: every cell here has to settle at the 44px row budget, and
      // a span that inherits the 1.5 line-height from `body` does not.
      render: n => <span className="font-medium text-fg-strong leading-5">{n.title}</span>,
    },
    {
      key: 'body',
      header: 'Body',
      // `RecordsTable` truncates every cell at 22rem, so the whole message has
      // to survive on the `title` - a broadcast body is routinely longer than
      // that and the cell would otherwise be lossy with no way to see the rest.
      render: n => <span className="text-fg leading-5" title={n.body}>{n.body}</span>,
    },
    {
      key: 'user',
      header: 'User',
      render: n => <span className="text-fg">{n.profiles?.full_name ?? '—'}</span>,
    },
    {
      key: 'read',
      header: 'Read',
      render: n => (
        /* `leading-4`, so the badge is a 16px line box plus its 4px of padding
           = 20px, which is the whole row budget. Left on the inherited 1.5 the
           badge is 22px of content and every row is 3px over. */
        <span className={`px-2 py-0.5 rounded-full text-xs font-medium leading-4 ${
          n.read ? 'bg-[#22C55E]/15 text-accent-green' : 'bg-[#F59E0B]/15 text-accent-amber'
        }`}>
          {n.read ? 'Read' : 'Unread'}
        </span>
      ),
    },
    {
      key: 'date',
      header: 'Date',
      align: 'right',
      render: n => <span className="text-fg-muted whitespace-nowrap leading-5">{new Date(n.created_at).toLocaleString()}</span>,
    },
  ]

  return (
    <div className="h-full min-h-0 flex flex-col gap-3">
      <div className="glass-card p-4 rounded-xl w-1/2 shrink-0">
        <h2 className="text-base font-semibold mb-3 text-fg-strong">Send Notification</h2>
        <div className="space-y-3">
          <div>
            <label className="block text-sm font-medium text-fg mb-1">Target</label>
            <div className="flex gap-2">
              {(['all', 'member', 'trainer'] as const).map(role => (
                <button
                  key={role}
                  onClick={() => setTargetRole(role)}
                  className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm border transition-colors cursor-pointer ${
                    targetRole === role
                      ? 'bg-[#7C3AED] border-[#7C3AED] text-white'
                      : 'bg-overlay-8 border-line text-fg hover:border-fg-muted'
                  }`}
                >
                  <Users className="w-4 h-4" />
                  {role === 'all' ? 'All Users' : role === 'member' ? 'Members' : 'Trainers'}
                </button>
              ))}
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-fg mb-1">Title</label>
            <input
              value={title}
              onChange={e => setTitle(e.target.value)}
              className="w-full px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50"
              placeholder="Notification title..."
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-fg mb-1">Message</label>
            <textarea
              value={body}
              onChange={e => setBody(e.target.value)}
              className="w-full px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50 min-h-[100px]"
              placeholder="Notification message body..."
            />
          </div>
          <button
            onClick={handleSend}
            disabled={sending || !title.trim() || !body.trim()}
            className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-[#7C3AED] to-[#3B82F6] text-white rounded-lg text-sm hover:opacity-90 disabled:opacity-50 transition-opacity"
          >
            {sending ? (
              <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
            ) : (
              <Send className="w-4 h-4" />
            )}
            {sending ? 'Sending...' : 'Send Notification'}
          </button>
        </div>
      </div>

      <RecordsTable
        title="Recent Notifications"
        columns={columns}
        rows={rows}
        rowKey={n => n.id}
        searchFields={n => [n.title, n.body, n.profiles?.full_name]}
        searchPlaceholder="Search by title, message or user…"
        searchValue={search}
        onSearchChange={setSearch}
        isLoading={isLoading}
        emptyMessage={rows.length === 0
          ? 'No notifications sent yet'
          : 'No notifications match this search'}
      />
    </div>
  )
}
