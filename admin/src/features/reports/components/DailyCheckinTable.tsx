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
    <div className="glass-card rounded-xl">
      <div className="px-4 py-3 border-b border-line flex items-center justify-between">
        <h2 className="font-semibold text-fg-strong">Attendance Activity</h2>
        {!isLoading && (
          <span className="text-xs text-fg-muted">{data.length} members checked in</span>
        )}
      </div>
      {isLoading ? (
        <div className="text-center py-8 text-fg-muted">Loading...</div>
      ) : data.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 gap-3">
          <span className="flex items-center justify-center w-10 h-10 rounded-full bg-overlay-8 text-fg-faint">
            <Inbox className="w-5 h-5" strokeWidth={1.75} />
          </span>
          <p className="text-sm text-fg-faint">No attendance recorded this month</p>
        </div>
      ) : (
        <table className="w-full">
          <thead>
            <tr className="border-b border-line bg-overlay-5">
              <th className="text-left px-4 py-3 text-sm font-medium text-fg-muted">Member</th>
              <th className="text-center px-4 py-3 text-sm font-medium text-fg-muted">Check-ins</th>
              <th className="text-right px-4 py-3 text-sm font-medium text-fg-muted">Last Check-in</th>
            </tr>
          </thead>
          <tbody>
            {data.map(row => (
              <tr key={row.memberId} className="border-b border-line-soft last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                <td className="px-4 py-3 text-sm font-medium text-fg-strong">{row.name}</td>
                <td className="px-4 py-3 text-center">
                  <span className="inline-flex items-center gap-1.5 text-sm font-semibold">
                    <CalendarCheck className="w-3.5 h-3.5 text-accent-purple" />
                    <span className="text-fg-strong">{row.count}</span>
                  </span>
                </td>
                <td className="px-4 py-3 text-sm text-right text-fg">
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
