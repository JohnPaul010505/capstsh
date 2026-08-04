import { CalendarCheck, Inbox } from 'lucide-react'

interface CheckinRow {
  memberId: string
  name: string
  count: number
  lastCheckIn: string
}

interface DailyCheckinTableProps {
  data: CheckinRow[]
  isLoading: boolean
}

export function DailyCheckinTable({ data, isLoading }: DailyCheckinTableProps) {
  return (
    <div className="glass-card rounded-xl border border-white/10 shadow-sm">
      <div className="px-4 py-3 border-b border-white/10 flex items-center justify-between">
        <h2 className="font-semibold text-[#ECECFC]">Attendance Activity</h2>
        {!isLoading && (
          <span className="text-xs text-[#55557A]">{data.length} members checked in</span>
        )}
      </div>
      {isLoading ? (
        <div className="text-center py-8 text-[#55557A]">Loading...</div>
      ) : data.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 gap-3">
          <span className="flex items-center justify-center w-10 h-10 rounded-full bg-white/[0.08] text-[#5A5A82]">
            <Inbox className="w-5 h-5" strokeWidth={1.75} />
          </span>
          <p className="text-sm text-[#8888B3]">No attendance recorded this month</p>
        </div>
      ) : (
        <table className="w-full">
          <thead>
            <tr className="border-b border-white/10 bg-white/5">
              <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Member</th>
              <th className="text-center px-4 py-3 text-sm font-medium text-[#55557A]">Check-ins</th>
              <th className="text-right px-4 py-3 text-sm font-medium text-[#55557A]">Last Check-in</th>
            </tr>
          </thead>
          <tbody>
            {data.map(row => (
              <tr key={row.memberId} className="border-b border-white/5 last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                <td className="px-4 py-3 text-sm font-medium text-[#ECECFC]">{row.name}</td>
                <td className="px-4 py-3 text-center">
                  <span className="inline-flex items-center gap-1.5 text-sm font-semibold">
                    <CalendarCheck className="w-3.5 h-3.5 text-[#C084FC]" />
                    <span className="text-[#ECECFC]">{row.count}</span>
                  </span>
                </td>
                <td className="px-4 py-3 text-sm text-right text-[#B4B4D0]">
                  {new Date(row.lastCheckIn).toLocaleDateString()}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}
