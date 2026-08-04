import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  PieChart, Pie, Cell, Legend, AreaChart, Area,
} from 'recharts'
import StatusBadge from '@/components/StatusBadge'

const COLORS = ['#7C3AED', '#22C55E', '#F59E0B', '#EF4444', '#3B82F6', '#C084FC']
const DAY = 24 * 60 * 60 * 1000

export default function ReportsPage() {
  const { data: membershipData } = useQuery({
    queryKey: ['report-memberships'],
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

  const { data: genderData } = useQuery({
    queryKey: ['report-gender'],
    queryFn: async () => {
      const { data } = await supabase.from('profiles').select('gender').eq('role', 'member')
      const m = data?.filter(p => p.gender === 'male').length ?? 0
      const f = data?.filter(p => p.gender === 'female').length ?? 0
      const o = data?.filter(p => p.gender && !['male', 'female'].includes(p.gender)).length ?? 0
      return [
        { name: 'Male', value: m },
        { name: 'Female', value: f },
        { name: 'Other', value: o },
      ].filter(d => d.value > 0)
    },
  })

  const { data: memberCount } = useQuery({
    queryKey: ['report-member-count'],
    queryFn: async () => {
      const { count } = await supabase
        .from('profiles')
        .select('id', { count: 'exact', head: true })
        .eq('role', 'member')
      return count ?? 0
    },
  })

  const { data: attendanceTrend } = useQuery({
    queryKey: ['report-attendance-trend'],
    queryFn: async () => {
      const thirtyDaysAgo = new Date()
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 29)
      const { data } = await supabase
        .from('attendance')
        .select('check_in_date')
        .gte('check_in_date', thirtyDaysAgo.toISOString().split('T')[0])
        .order('check_in_date', { ascending: true })

      const counts: Record<string, number> = {}
      data?.forEach(a => {
        counts[a.check_in_date] = (counts[a.check_in_date] || 0) + 1
      })
      const days = []
      for (let i = 29; i >= 0; i--) {
        const d = new Date()
        d.setDate(d.getDate() - i)
        const key = d.toISOString().split('T')[0]
        days.push({ date: key, checkins: counts[key] || 0 })
      }
      return days
    },
  })

  const { data: expiringData } = useQuery({
    queryKey: ['report-expiring'],
    queryFn: async () => {
      const { data } = await supabase
        .from('memberships')
        .select('id, plan_name, end_date, profiles!memberships_member_id_fkey(full_name, code)')
        .eq('status', 'active')
        .not('end_date', 'is', null)
        .not('plan_name', 'eq', 'Daily')
        .order('end_date', { ascending: true })

      const today = new Date()
      today.setHours(0, 0, 0, 0)
      const cutoff = today.getTime() + 30 * DAY
      return (data ?? [])
        .filter(m => {
          const end = new Date(m.end_date)
          return end.getTime() >= today.getTime() && end.getTime() <= cutoff
        })
        .map(m => {
          const profiles = Array.isArray(m.profiles) ? m.profiles[0] : m.profiles
          return { ...m, profiles: profiles ?? null, daysLeft: Math.ceil((new Date(m.end_date).getTime() - today.getTime()) / DAY) }
        })
    },
  })

  const { data: inactiveData } = useQuery({
    queryKey: ['report-inactive'],
    queryFn: async () => {
      const ninetyDaysAgo = new Date(Date.now() - 90 * DAY).toISOString().split('T')[0]
      const [membershipsRes, attendanceRes] = await Promise.all([
        supabase
          .from('memberships')
          .select('member_id, plan_name')
          .eq('plan_name', 'Daily'),
        supabase
          .from('attendance')
          .select('member_id, check_in_date')
          .gte('check_in_date', ninetyDaysAgo)
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
            member_id: m.member_id,
            name: profileMap[m.member_id]?.full_name ?? 'Unknown',
            code: profileMap[m.member_id]?.code,
            plan_name: m.plan_name,
            lastCheckIn: last ?? null,
            daysInactive,
          }
        })
        .filter(r => r.daysInactive >= 7)
        .sort((a, b) => b.daysInactive - a.daysInactive)
    },
  })

  const totalRevenue = membershipData?.reduce((sum, m) => sum + m.revenue, 0) ?? 0

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-[#ECECFC]">Reports & Analytics</h1>
        <p className="text-[#55557A] text-sm mt-1">Track membership trends, revenue, and member activity</p>
      </div>

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

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 grid grid-cols-1 md:grid-cols-2 gap-6 content-start">
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

          <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm">
            <h2 className="text-lg font-semibold mb-4 text-[#ECECFC]">Member Growth (30-day)</h2>
            <div className="h-72">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={attendanceTrend ?? []}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#2A2A45" />
                  <XAxis dataKey="date" tick={{ fill: '#55557A', fontSize: 12 }} tickFormatter={v => new Date(v).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })} />
                  <YAxis tick={{ fill: '#55557A', fontSize: 12 }} />
                  <Tooltip contentStyle={{ backgroundColor: '#1C1C35', border: '1px solid #2A2A45', borderRadius: '8px', color: '#ECECFC' }} labelStyle={{ color: '#B4B4D0' }} />
                  <Area type="monotone" dataKey="checkins" stroke="#3B82F6" fill="#3B82F6" fillOpacity={0.15} strokeWidth={2} />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>

          <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm">
            <h2 className="text-lg font-semibold mb-4 text-[#ECECFC]">Gender Distribution</h2>
            <div className="h-72">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie data={genderData ?? []} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={90} innerRadius={50} paddingAngle={3}>
                    {genderData?.map((_, i) => (<Cell key={i} fill={COLORS[i % COLORS.length]} />))}
                  </Pie>
                  <Tooltip contentStyle={{ backgroundColor: '#1C1C35', border: '1px solid #2A2A45', borderRadius: '8px', color: '#ECECFC' }} />
                  <Legend formatter={(value) => <span style={{ color: '#B4B4D0' }}>{value}</span>} />
                </PieChart>
              </ResponsiveContainer>
            </div>
          </div>
        </div>

        <div className="space-y-6">
          <div className="glass-card rounded-xl border border-white/10 shadow-sm">
            <div className="px-5 py-4 border-b border-white/10">
              <h2 className="text-lg font-semibold text-[#ECECFC]">Expiring Memberships</h2>
              <p className="text-sm text-[#55557A] mt-0.5">Active memberships with a fixed end date in the next 30 days</p>
            </div>            {expiringData && expiringData.length === 0 ? (
              <p className="px-5 py-8 text-center text-sm text-[#55557A]">No memberships expiring soon</p>
            ) : (
              <table className="w-full">
                <thead>
                  <tr className="border-b border-white/10 bg-white/5">
                    <th className="text-left px-5 py-3 text-sm font-medium text-[#55557A]">Member</th>
                    <th className="text-left px-5 py-3 text-sm font-medium text-[#55557A]">Plan</th>
                    <th className="text-left px-5 py-3 text-sm font-medium text-[#55557A]">Ends</th>
                    <th className="text-right px-5 py-3 text-sm font-medium text-[#55557A]">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {expiringData?.map(m => (
                    <tr key={m.id} className="border-b border-white/5 last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                      <td className="px-5 py-3">
                        <p className="text-sm font-medium text-[#ECECFC]">{m.profiles?.full_name ?? 'Unknown'}</p>
                        <p className="text-xs font-mono text-[#55557A]">{m.profiles?.code}</p>
                      </td>
                      <td className="px-5 py-3 text-sm text-[#B4B4D0]">{m.plan_name}</td>
                      <td className="px-5 py-3 text-sm text-[#B4B4D0] whitespace-nowrap">{new Date(m.end_date).toLocaleDateString()}</td>
                      <td className="px-5 py-3 text-right">
                        <StatusBadge status={m.daysLeft <= 7 ? 'expiring' : 'ending_soon'} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>

          <div className="glass-card rounded-xl border border-white/10 shadow-sm">
            <div className="px-5 py-4 border-b border-white/10">
              <h2 className="text-lg font-semibold text-[#ECECFC]">Inactive Members</h2>
              <p className="text-sm text-[#55557A] mt-0.5">Daily-plan members with no check-in in the last 7 days</p>
            </div>
            {inactiveData && inactiveData.length === 0 ? (
              <p className="px-5 py-8 text-center text-sm text-[#55557A]">No inactive members</p>
            ) : (
              <table className="w-full">
                <thead>
                  <tr className="border-b border-white/10 bg-white/5">
                    <th className="text-left px-5 py-3 text-sm font-medium text-[#55557A]">Member</th>
                    <th className="text-left px-5 py-3 text-sm font-medium text-[#55557A]">Last check-in</th>
                    <th className="text-left px-5 py-3 text-sm font-medium text-[#55557A]">Days inactive</th>
                    <th className="text-right px-5 py-3 text-sm font-medium text-[#55557A]">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {inactiveData?.map(m => (
                    <tr key={m.member_id} className="border-b border-white/5 last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                      <td className="px-5 py-3">
                        <p className="text-sm font-medium text-[#ECECFC]">{m.name}</p>
                        <p className="text-xs font-mono text-[#55557A]">{m.code}</p>
                      </td>
                      <td className="px-5 py-3 text-sm text-[#B4B4D0] whitespace-nowrap">
                        {m.lastCheckIn ? new Date(m.lastCheckIn).toLocaleDateString() : 'Never'}
                      </td>
                      <td className="px-5 py-3 text-sm text-[#FBBF24] font-medium">{m.daysInactive} days</td>
                      <td className="px-5 py-3 text-right">
                        <StatusBadge status="inactive" />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
