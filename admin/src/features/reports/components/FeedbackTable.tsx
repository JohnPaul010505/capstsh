import { MessageSquare, Inbox } from 'lucide-react'

interface FeedbackRow {
  id: string
  trainer_id: string
  member_id: string
  content: string
  created_at: string
  profiles?: { full_name: string }
}

interface FeedbackTableProps {
  data: FeedbackRow[]
  isLoading: boolean
}

export function FeedbackTable({ data, isLoading }: FeedbackTableProps) {
  return (
    <div className="glass-card rounded-xl border border-white/10 shadow-sm">
      <div className="px-4 py-3 border-b border-white/10 flex items-center justify-between">
        <h2 className="font-semibold text-[#ECECFC]">Recent Feedback</h2>
        {!isLoading && (
          <span className="text-xs text-[#55557A]">{data.length} entries</span>
        )}
      </div>
      {isLoading ? (
        <div className="text-center py-8 text-[#55557A]">Loading...</div>
      ) : data.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 gap-3">
          <span className="flex items-center justify-center w-10 h-10 rounded-full bg-white/[0.08] text-[#5A5A82]">
            <Inbox className="w-5 h-5" strokeWidth={1.75} />
          </span>
          <p className="text-sm text-[#8888B3]">No feedback recorded yet</p>
        </div>
      ) : (
        <table className="w-full">
          <thead>
            <tr className="border-b border-white/10 bg-white/5">
              <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Member</th>
              <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Feedback</th>
              <th className="text-right px-4 py-3 text-sm font-medium text-[#55557A]">Date</th>
            </tr>
          </thead>
          <tbody>
            {data.map(f => (
              <tr key={f.id} className="border-b border-white/5 last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                <td className="px-4 py-3 text-sm font-medium text-[#ECECFC]">{f.profiles?.full_name ?? 'Unknown'}</td>
                <td className="px-4 py-3 text-sm text-[#B4B4D0] flex items-start gap-2">
                  <MessageSquare className="w-3.5 h-3.5 text-[#55557A] mt-0.5 shrink-0" />
                  <span>{f.content}</span>
                </td>
                <td className="px-4 py-3 text-sm text-right text-[#B4B4D0] whitespace-nowrap">
                  {new Date(f.created_at).toLocaleDateString()}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}
