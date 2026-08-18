import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import StatusBadge from '@/components/StatusBadge'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from 'recharts'

const DAY = 24 * 60 * 60 * 1000

export default function InactiveReportPage() {
  const [tab, setTab] = useState<'reports' | 'analytics'>('reports')
  const [subTab, setSubTab] = useState<'members' | 'trainers'>('members')
  const [notifiedUserIds, setNotifiedUserIds] = useState<Set<string>>(new Set())

  const { data: inactiveMembers } = useQuery({
    queryKey: ['report-inactive-members'],
    enabled: tab === 'reports' && subTab === 'members',
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
    enabled: tab === 'reports' && subTab === 'trainers',
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

  const { data: membershipData } = useQuery({
    queryKey: ['analytics-memberships'],
    enabled: tab === 'analytics',
    queryFn: async () => {
      const { data } = await supabase.from('memberships').select('plan_name, price')
      const planMap: Record<string, { count: number; revenue: number }> = {}
      data?.forEach(m => {
        if (!planMap[m.plan_name]) planMap[m.plan_name] = { count: 0, revenue: 0 }
        planMap[m.plan_name].count++
        planMap[m.plan_name].revenue += Number(m.price)
      })
      return Object.entries(planMap).map(([name, v]) => ({ name, count: v.count, revenue: v.revenue }))
    },
  })

  const { data: memberCount } = useQuery({
    queryKey: ['analytics-member-count'],
    enabled: tab === 'analytics',
    queryFn: async () => {
      const { count } = await supabase
        .from('profiles')
        .select('id', { count: 'exact', head: true })
        .eq('role', 'member')
      return count ?? 0
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
  const totalRevenue = membershipData?.reduce((sum, m) => sum + m.revenue, 0) ?? 0

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[#ECECFC]">
            {tab === 'reports' ? 'Reports' : 'Analytics'}
          </h1>
          <p className="text-[#55557A] text-sm mt-1">
            {tab === 'reports'
              ? 'Inactive members and trainers'
              : 'Membership trends, revenue, and plan distribution'}
          </p>
        </div>
        <button
          onClick={() => setTab(tab === 'reports' ? 'analytics' : 'reports')}
          className="px-4 py-1.5 rounded-lg text-sm font-medium border transition-colors
            bg-[#7C3AED]/20 border-[#7C3AED] text-[#C084FC] hover:bg-[#7C3AED]/30"
        >
          {tab === 'reports' ? 'Analytics' : 'Reports'}
        </button>
      </div>

      {tab === 'reports' ? (
        <div className="glass-card rounded-xl border border-white/10 shadow-sm">
          <div className="px-5 py-4 border-b border-white/10 flex items-center gap-3">
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

          {!rows ? (
            <div className="px-5 py-8 text-center text-sm text-[#55557A]">Loading...</div>
          ) : rows.length === 0 ? (
            <div className="px-5 py-8 text-center text-sm text-[#55557A]">No inactive {subTab === 'members' ? 'members' : 'trainers'}</div>
          ) : (
            <table className="w-full">
              <thead>
                <tr className="border-b border-white/10 bg-white/5">
                  <th className="text-left px-5 py-3 text-sm font-medium text-[#55557A]">{label}</th>
                  <th className="text-left px-5 py-3 text-sm font-medium text-[#55557A]">Last check-in</th>
                  <th className="text-left px-5 py-3 text-sm font-medium text-[#55557A]">Days inactive</th>
                  <th className="text-right px-5 py-3 text-sm font-medium text-[#55557A]">Status</th>
                  <th className="text-right px-5 py-3 text-sm font-medium text-[#55557A]">Action</th>
                </tr>
              </thead>
              <tbody>
                {rows?.map(r => (
                  <tr key={r.userId} className="border-b border-white/5 last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                    <td className="px-5 py-3">
                      <p className="text-sm font-medium text-[#ECECFC]">{r.name}</p>
                      <p className="text-xs font-mono text-[#55557A]">{r.code}</p>
                    </td>
                    <td className="px-5 py-3 text-sm text-[#B4B4D0] whitespace-nowrap">
                      {r.lastCheckIn ? new Date(r.lastCheckIn).toLocaleDateString() : 'Never'}
                    </td>
                    <td className="px-5 py-3 text-sm text-[#FBBF24] font-medium">{r.daysInactive} days</td>
                    <td className="px-5 py-3 text-right">
                      <StatusBadge status="inactive" />
                    </td>
                    <td className="px-5 py-3 text-right">
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
          )}
        </div>
      ) : (
        <div className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm">
              <p className="text-sm text-[#55557A]">Total Plans</p>
              <p className="text-2xl font-bold text-[#ECECFC] mt-1">{membershipData?.length ?? 0}</p>
            </div>
            <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm">
              <p className="text-sm text-[#55557A]">Total Revenue</p>
              <p className="text-2xl font-bold text-[#22C55E] mt-1">${totalRevenue.toLocaleString()}</p>
            </div>
            <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm">
              <p className="text-sm text-[#55557A]">Total Members</p>
              <p className="text-2xl font-bold text-[#ECECFC] mt-1">{memberCount ?? 0}</p>
            </div>
            <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm">
              <p className="text-sm text-[#55557A]">Avg Revenue/Member</p>
              <p className="text-2xl font-bold text-[#C084FC] mt-1">
                ${memberCount && memberCount > 0 ? (totalRevenue / memberCount).toFixed(0) : '0'}
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm">
              <h2 className="text-lg font-semibold mb-4 text-[#ECECFC]">Membership Plans</h2>
              <div className="h-72">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={membershipData ?? []}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#2A2A45" />
                    <XAxis dataKey="name" tick={{ fill: '#55557A', fontSize: 12 }} />
                    <YAxis tick={{ fill: '#55557A', fontSize: 12 }} />
                    <Tooltip contentStyle={{ backgroundColor: '#1C1C35', border: '1px solid #2A2A45', borderRadius: '8px', color: '#ECECFC' }} labelStyle={{ color: '#B4B4D0' }} />
                    <Bar dataKey="count" fill="url(#reportPurple)" radius={[4, 4, 0, 0]} />
                    <defs>
                      <linearGradient id="reportPurple" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor="#7C3AED" />
                        <stop offset="100%" stopColor="#7C3AED" stopOpacity={0.3} />
                      </linearGradient>
                    </defs>
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </div>

            <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm">
              <h2 className="text-lg font-semibold mb-4 text-[#ECECFC]">Revenue by Plan</h2>
              <div className="h-72">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={membershipData ?? []}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#2A2A45" />
                    <XAxis dataKey="name" tick={{ fill: '#55557A', fontSize: 12 }} />
                    <YAxis tick={{ fill: '#55557A', fontSize: 12 }} tickFormatter={v => `$${v}`} />
                    <Tooltip contentStyle={{ backgroundColor: '#1C1C35', border: '1px solid #2A2A45', borderRadius: '8px', color: '#ECECFC' }} labelStyle={{ color: '#B4B4D0' }} formatter={(v: number) => [`$${v}`, 'Revenue']} />
                    <Bar dataKey="revenue" fill="url(#revenueGreen)" radius={[4, 4, 0, 0]} />
                    <defs>
                      <linearGradient id="revenueGreen" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor="#22C55E" />
                        <stop offset="100%" stopColor="#22C55E" stopOpacity={0.3} />
                      </linearGradient>
                    </defs>
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
