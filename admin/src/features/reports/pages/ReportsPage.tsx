import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from 'recharts'

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

  const totalRevenue = membershipData?.reduce((sum, m) => sum + m.revenue, 0) ?? 0

  return (
    <div className="space-y-3">
      <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
        <div className="glass-card p-4 rounded-xl border border-white/10 shadow-sm">
          <p className="text-xs text-[#55557A]">Total Plans</p>
          <p className="text-xl font-bold text-[#ECECFC] mt-1">{membershipData?.length ?? 0}</p>
        </div>
        <div className="glass-card p-4 rounded-xl border border-white/10 shadow-sm">
          <p className="text-xs text-[#55557A]">Total Revenue</p>
          <p className="text-xl font-bold text-[#22C55E] mt-1">${totalRevenue.toLocaleString()}</p>
        </div>
        <div className="glass-card p-4 rounded-xl border border-white/10 shadow-sm">
          <p className="text-xs text-[#55557A]">Total Members</p>
          <p className="text-xl font-bold text-[#ECECFC] mt-1">{memberCount ?? 0}</p>
        </div>
        <div className="glass-card p-4 rounded-xl border border-white/10 shadow-sm">
          <p className="text-xs text-[#55557A]">Avg Revenue/Member</p>
          <p className="text-xl font-bold text-[#C084FC] mt-1">
            ${memberCount && memberCount > 0 ? (totalRevenue / memberCount).toFixed(0) : '0'}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        <div className="glass-card p-4 rounded-xl border border-white/10 shadow-sm">
          <h2 className="text-base font-semibold mb-3 text-[#ECECFC]">Membership Plans</h2>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={membershipData ?? []}>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
                <XAxis dataKey="name" tick={{ fill: '#9494BD', fontSize: 12 }} axisLine={{ stroke: 'rgba(255,255,255,0.06)' }} tickLine={false} />
                <YAxis tick={{ fill: '#9494BD', fontSize: 12 }} axisLine={false} tickLine={false} width={32} />
                <Tooltip contentStyle={{ backgroundColor: 'rgba(20,20,42,0.9)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 10, color: '#ECECFC' }} labelStyle={{ color: '#B4B4D0' }} />
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

        <div className="glass-card p-4 rounded-xl border border-white/10 shadow-sm">
          <h2 className="text-base font-semibold mb-3 text-[#ECECFC]">Revenue by Plan</h2>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={membershipData ?? []}>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
                <XAxis dataKey="name" tick={{ fill: '#9494BD', fontSize: 12 }} axisLine={{ stroke: 'rgba(255,255,255,0.06)' }} tickLine={false} />
                <YAxis tick={{ fill: '#9494BD', fontSize: 12 }} axisLine={false} tickLine={false} width={32} tickFormatter={v => `$${v}`} />
                <Tooltip contentStyle={{ backgroundColor: 'rgba(20,20,42,0.9)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 10, color: '#ECECFC' }} labelStyle={{ color: '#B4B4D0' }} formatter={(v: number) => [`$${v}`, 'Revenue']} />
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
  )
}
