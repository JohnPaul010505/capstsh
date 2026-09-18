import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { Bell, Send, Users } from 'lucide-react'

export default function NotificationsPage() {
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [targetRole, setTargetRole] = useState<'all' | 'member' | 'trainer'>('all')
  const [sending, setSending] = useState(false)
  const queryClient = useQueryClient()

  const { data: sentNotifications } = useQuery({
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

  return (
    <div className="space-y-3">
      <div className="glass-card p-4 rounded-xl">
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

      <div className="glass-card rounded-xl overflow-hidden flex flex-col min-h-0">
        <div className="px-4 py-3 border-b border-line flex items-center gap-2">
          <Bell className="w-4 h-4 text-accent-purple" />
          <h2 className="font-semibold text-fg-strong">Recent Notifications</h2>
        </div>
        <div className="overflow-x-auto flex-1 max-h-[420px]">
          <table className="w-full">
            <thead>
              <tr className="border-b border-line bg-overlay-5">
                <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Title</th>
                <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Body</th>
                <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">User</th>
                <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Read</th>
                <th className="text-right px-3 py-2 text-sm font-medium text-fg-muted">Date</th>
              </tr>
            </thead>
            <tbody>
              {sentNotifications?.map(n => (
                <tr key={n.id} className="border-b border-line-soft last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                  <td className="px-3 py-2 text-sm font-medium text-fg-strong">{n.title}</td>
                  <td className="px-3 py-2 text-sm text-fg max-w-xs truncate">{n.body}</td>
                  <td className="px-3 py-2 text-sm text-fg">{n.profiles?.full_name ?? '—'}</td>
                  <td className="px-3 py-2">
                    <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                      n.read ? 'bg-[#22C55E]/15 text-accent-green' : 'bg-[#F59E0B]/15 text-accent-amber'
                    }`}>
                      {n.read ? 'Read' : 'Unread'}
                    </span>
                  </td>
                  <td className="px-3 py-2 text-sm text-fg-muted text-right whitespace-nowrap">
                    {new Date(n.created_at).toLocaleString()}
                  </td>
                </tr>
              ))}
              {sentNotifications?.length === 0 && (
                <tr><td colSpan={5} className="px-3 py-6 text-center text-fg-muted">No notifications sent yet</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
