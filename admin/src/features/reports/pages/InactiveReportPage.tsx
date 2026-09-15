import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import StatusBadge from '@/components/StatusBadge'

const DAY = 24 * 60 * 60 * 1000

export default function InactiveReportPage() {
  const [subTab, setSubTab] = useState<'members' | 'trainers'>('members')
  const [notifiedUserIds, setNotifiedUserIds] = useState<Set<string>>(new Set())

  const { data: inactiveMembers } = useQuery({
    queryKey: ['report-inactive-members'],
    enabled: subTab === 'members',
    queryFn: async () => {
      const sevenDaysAgo = new Date(Date.now() - 7 * DAY).toISOString().split('T')[0]
      const [membershipsRes, attendanceRes] = await Promise.all([
        supabase
          .from('memberships')
          .select('member_id, plan_name')
          .eq('plan_name', 'Daily')
          .eq('status', 'active'),
        supabase
          .from('attendance')
          .select('member_id, check_in_date')
          .gte('check_in_date', sevenDaysAgo)
          .order('check_in_date', { ascending: false }),
      ])

      const lastCheckIn: Record<string, string> = {}
      attendanceRes.data?.forEach(a => {
        if (!lastCheckIn[a.member_id] || a.check_in_date > lastCheckIn[a.member_id]) {
          lastCheckIn[a.member_id] = a.check_in_date
        }
      })

      const memberIds = membershipsRes.data?.map(m => m.member_id) ?? []
      let profileMap: Record<string, { full_name: string; code: string }> = {}
      if (memberIds.length > 0) {
        const { data: profiles } = await supabase
          .from('profiles')
          .select('id, full_name, code')
          .in('id', memberIds)
        profiles?.forEach(p => { profileMap[p.id] = p })
      }

      const now = new Date()
      now.setHours(0, 0, 0, 0)
      return (membershipsRes.data ?? [])
        .map(m => {
          const last = lastCheckIn[m.member_id]
          const daysInactive = last
            ? Math.floor((now.getTime() - new Date(last).getTime()) / DAY)
            : 999
          return {
            userId: m.member_id,
            name: profileMap[m.member_id]?.full_name ?? 'Unknown',
            code: profileMap[m.member_id]?.code,
            lastCheckIn: last ?? null,
            daysInactive,
          }
        })
        .filter(r => r.daysInactive >= 7)
        .sort((a, b) => b.daysInactive - a.daysInactive)
    },
  })

  const { data: inactiveTrainers } = useQuery({
    queryKey: ['report-inactive-trainers'],
    enabled: subTab === 'trainers',
    queryFn: async () => {
      const sevenDaysAgo = new Date(Date.now() - 7 * DAY).toISOString().split('T')[0]
      const { data: trainers } = await supabase
        .from('profiles')
        .select('id, full_name, code')
        .eq('role', 'trainer')

      const trainerIds = (trainers ?? []).map(t => t.id)
      let attendanceData: { member_id: string; check_in_date: string }[] = []
      if (trainerIds.length > 0) {
        const { data } = await supabase
          .from('attendance')
          .select('member_id, check_in_date')
          .in('member_id', trainerIds)
          .gte('check_in_date', sevenDaysAgo)
          .order('check_in_date', { ascending: false })
        attendanceData = data ?? []
      }

      const lastCheckIn: Record<string, string> = {}
      attendanceData.forEach(a => {
        if (!lastCheckIn[a.member_id] || a.check_in_date > lastCheckIn[a.member_id]) {
          lastCheckIn[a.member_id] = a.check_in_date
        }
      })

      const profileMap: Record<string, { full_name: string; code: string }> = {}
      trainers?.forEach(t => { profileMap[t.id] = t })

      const now = new Date()
      now.setHours(0, 0, 0, 0)
      return (trainers ?? [])
        .map(t => {
          const last = lastCheckIn[t.id]
          const daysInactive = last
            ? Math.floor((now.getTime() - new Date(last).getTime()) / DAY)
            : 999
          return {
            userId: t.id,
            name: profileMap[t.id]?.full_name ?? 'Unknown',
            code: profileMap[t.id]?.code,
            lastCheckIn: last ?? null,
            daysInactive,
          }
        })
        .filter(r => r.daysInactive >= 7)
        .sort((a, b) => b.daysInactive - a.daysInactive)
    },
  })

  const handleNotify = async (userId: string, daysInactive: number) => {
    try {
      const res = await fetch('/api/notifications/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId,
          title: 'Stay on Track!',
          body: `You've been inactive for a while in ${daysInactive} days. Let's get moving again!`,
        }),
      })
      if (!res.ok) {
        const err = await res.json().catch(() => ({}))
        throw new Error(err.error || 'Failed to send notification')
      }
      setNotifiedUserIds(prev => new Set(prev).add(userId))
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to send notification')
    }
  }

  const rows = subTab === 'members' ? inactiveMembers : inactiveTrainers
  const label = subTab === 'members' ? 'Member' : 'Trainer'

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <div />
      </div>

      {!rows ? (
        <div className="glass-card rounded-xl border border-white/10 shadow-sm overflow-hidden flex flex-col min-h-0">
          <div className="px-4 py-6 text-center text-sm text-[#55557A]">Loading...</div>
        </div>
      ) : rows.length === 0 ? (
        <div className="glass-card rounded-xl border border-white/10 shadow-sm overflow-hidden flex flex-col min-h-0">
          <div className="px-4 py-6 text-center text-sm text-[#55557A]">No inactive {subTab === 'members' ? 'members' : 'trainers'}</div>
        </div>
      ) : (
        <div className="glass-card rounded-xl border border-white/10 shadow-sm overflow-hidden flex flex-col min-h-0">
          <div className="px-4 py-3 border-b border-white/10 flex items-center gap-3">
            <button
              onClick={() => setSubTab('members')}
              className={`px-4 py-1.5 rounded-lg text-sm border transition-colors ${
                subTab === 'members'
                  ? 'bg-[#7C3AED]/20 border-[#7C3AED] text-[#C084FC]'
                  : 'bg-white/[0.08] border-white/10 text-[#B4B4D0] hover:border-[#55557A]'
              }`}
            >
              Inactive Members
            </button>
            <button
              onClick={() => setSubTab('trainers')}
              className={`px-4 py-1.5 rounded-lg text-sm border transition-colors ${
                subTab === 'trainers'
                  ? 'bg-[#7C3AED]/20 border-[#7C3AED] text-[#C084FC]'
                  : 'bg-white/[0.08] border-white/10 text-[#B4B4D0] hover:border-[#55557A]'
              }`}
            >
              Inactive Trainers
            </button>
          </div>

          <div className="overflow-x-auto flex-1 max-h-[420px]">
            <table className="w-full">
              <thead>
                <tr className="border-b border-white/10 bg-white/5">
                  <th className="text-left px-3 py-2 text-sm font-medium text-[#55557A]">{label}</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-[#55557A]">Last check-in</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-[#55557A]">Days inactive</th>
                  <th className="text-right px-3 py-2 text-sm font-medium text-[#55557A]">Status</th>
                  <th className="text-right px-3 py-2 text-sm font-medium text-[#55557A]">Action</th>
                </tr>
              </thead>
              <tbody>
                {rows?.map(r => (
                  <tr key={r.userId} className="border-b border-white/5 last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                    <td className="px-3 py-2">
                      <p className="text-sm font-medium text-[#ECECFC]">{r.name}</p>
                      <p className="text-xs font-mono text-[#55557A]">{r.code}</p>
                    </td>
                    <td className="px-3 py-2 text-sm text-[#B4B4D0] whitespace-nowrap">
                      {r.lastCheckIn ? new Date(r.lastCheckIn).toLocaleDateString() : 'Never'}
                    </td>
                    <td className="px-3 py-2 text-sm text-[#FBBF24] font-medium">{r.daysInactive} days</td>
                    <td className="px-3 py-2 text-right">
                      <StatusBadge status="inactive" />
                    </td>
                    <td className="px-3 py-2 text-right">
                      <button
                        onClick={() => handleNotify(r.userId, r.daysInactive)}
                        disabled={notifiedUserIds.has(r.userId)}
                        className="px-3 py-1.5 rounded-lg text-xs font-medium transition-colors
                          {notifiedUserIds.has(r.userId)
                            ? 'bg-white/[0.08] text-[#55557A] border border-white/10 cursor-not-allowed'
                            : 'bg-[#7C3AED]/20 text-[#C084FC] border border-[#7C3AED]/40 hover:bg-[#7C3AED]/30'}"
                      >
                        {notifiedUserIds.has(r.userId) ? 'Sent' : 'Notify'}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}
