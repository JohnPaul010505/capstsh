import { MessageSquare, Inbox } from 'lucide-react'

interface FeedbackRow {
  id: string
  trainer_id: string
  member_id: string
  content: string
  rating?: number | null
  rated_at?: string | null
  created_at: string
  member?: { full_name: string }
  trainer?: { full_name: string }
  profiles?: { full_name: string }
}

interface FeedbackTableProps {
  data: FeedbackRow[]
  isLoading: boolean
}

export function FeedbackTable({ data, isLoading }: FeedbackTableProps) {
  return (
    <div className="glass-card rounded-xl">
      <div className="px-4 py-3 border-b border-line flex items-center justify-between">
        <h2 className="font-semibold text-fg-strong">Recent Feedback</h2>
        {!isLoading && (
          <span className="text-xs text-fg-muted">{data.length} entries</span>
        )}
      </div>
      {isLoading ? (
        <div className="text-center py-8 text-fg-muted">Loading...</div>
      ) : data.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 gap-3">
          <span className="flex items-center justify-center w-10 h-10 rounded-full bg-overlay-8 text-fg-faint">
            <Inbox className="w-5 h-5" strokeWidth={1.75} />
          </span>
          <p className="text-sm text-fg-faint">No feedback recorded yet</p>
        </div>
      ) : (
        <div className="overflow-x-auto flex-1 max-h-[420px]">
          <table className="w-full">
            <thead>
              <tr className="border-b border-line bg-overlay-5">
                <th className="text-left px-4 py-3 text-sm font-medium text-fg-muted">Member</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-fg-muted">Trainer</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-fg-muted">Feedback</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-fg-muted">Rating</th>
                <th className="text-right px-4 py-3 text-sm font-medium text-fg-muted">Date</th>
              </tr>
            </thead>
            <tbody>
              {data.map(f => (
                <tr key={f.id} className="border-b border-line-soft last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                  <td className="px-4 py-3 text-sm font-medium text-fg-strong">{f.member?.full_name ?? f.profiles?.full_name ?? 'Unknown'}</td>
                  <td className="px-4 py-3 text-sm text-fg">{f.trainer?.full_name ?? '—'}</td>
                  <td className="px-4 py-3 text-sm text-fg flex items-start gap-2">
                    <MessageSquare className="w-3.5 h-3.5 text-fg-muted mt-0.5 shrink-0" />
                    <span>{f.content}</span>
                  </td>
                  <td className="px-4 py-3 text-sm whitespace-nowrap">
                    {f.rating ? (
                      <span className="inline-flex items-center gap-1">
                        <span className="text-[#FFC107]">
                          {'★'.repeat(f.rating)}
                          <span className="text-fg-faint">{'★'.repeat(5 - f.rating)}</span>
                        </span>
                        <span className="text-fg-muted">{f.rating}/5</span>
                      </span>
                    ) : (
                      <span className="text-fg-faint">Not rated</span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-sm text-right text-fg whitespace-nowrap">
                    {new Date(f.created_at).toLocaleDateString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
