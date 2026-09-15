import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { Shield, Filter } from 'lucide-react'
import { useState } from 'react'

export default function LogsPage() {
  const [actionFilter, setActionFilter] = useState('')

  const { data: logs, isLoading } = useQuery({
    queryKey: ['admin-logs', actionFilter],
    queryFn: async () => {
      let query = supabase
        .from('admin_logs')
        .select('*, profiles!admin_logs_admin_id_fkey(full_name)')
        .order('created_at', { ascending: false })
        .limit(100)
      if (actionFilter) {
        query = query.ilike('action', `%${actionFilter}%`)
      }
      const { data } = await query
      return data ?? []
    },
  })

  const { data: logActions } = useQuery({
    queryKey: ['admin-log-actions'],
    queryFn: async () => {
      const { data } = await supabase.from('admin_logs').select('action')
      const unique = new Set(data?.map(l => l.action) ?? [])
      return Array.from(unique).sort()
    },
  })

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <div />
        <div className="flex items-center gap-2">
          <Filter className="w-4 h-4 text-[#55557A]" />
          <select
            value={actionFilter}
            onChange={e => setActionFilter(e.target.value)}
            className="px-3 py-2 bg-white/[0.08] border border-white/10 rounded-lg text-sm text-[#ECECFC] focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50"
          >
            <option value="">All actions</option>
            {logActions?.map(a => <option key={a} value={a}>{a}</option>)}
          </select>
        </div>
      </div>

      {isLoading ? (
        <div className="text-center py-8 text-[#55557A]">Loading...</div>
      ) : (
        <div className="glass-card rounded-xl border border-white/10 shadow-sm overflow-hidden flex flex-col min-h-0">
          <div className="overflow-x-auto flex-1">
            <table className="w-full">
              <thead>
                <tr className="border-b border-white/10 bg-white/5">
                  <th className="text-left px-3 py-2 text-sm font-medium text-[#55557A]">Admin</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-[#55557A]">Action</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-[#55557A]">Target</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-[#55557A]">Details</th>
                  <th className="text-right px-3 py-2 text-sm font-medium text-[#55557A]">Date</th>
                </tr>
              </thead>
              <tbody>
                {logs?.map(log => (
                  <tr key={log.id} className="border-b border-white/5 last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                    <td className="px-3 py-2 text-sm font-medium text-[#ECECFC]">
                      <div className="flex items-center gap-2">
                        <Shield className="w-3.5 h-3.5 text-[#7C3AED]" />
                        {log.profiles?.full_name ?? 'Unknown'}
                      </div>
                    </td>
                    <td className="px-3 py-2 text-sm">
                      <span className="px-2 py-0.5 rounded-full text-xs font-medium bg-[#7C3AED]/15 text-[#C084FC]">
                        {log.action}
                      </span>
                    </td>
                    <td className="px-3 py-2 text-sm text-[#B4B4D0] capitalize">{log.target_type ?? '—'}</td>
                    <td className="px-3 py-2 text-sm text-[#B4B4D0] max-w-xs truncate">
                      {log.details ? JSON.stringify(log.details) : '—'}
                    </td>
                    <td className="px-3 py-2 text-sm text-[#55557A] text-right whitespace-nowrap">
                      {new Date(log.created_at).toLocaleString()}
                    </td>
                  </tr>
                ))}
                {logs?.length === 0 && (
                  <tr><td colSpan={5} className="px-3 py-6 text-center text-[#55557A]">No activity logs yet</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}
