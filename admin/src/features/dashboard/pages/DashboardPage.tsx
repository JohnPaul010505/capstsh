import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { supabase } from '@/lib/supabase'
import { Users, Dumbbell, CalendarCheck, TrendingUp, Activity } from 'lucide-react'
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,

  PieChart, Pie, Cell,
} from 'recharts'
import StatsCard from '@/components/StatsCard'
import ChartCard from '@/components/ChartCard'
import StatusBadge from '@/components/StatusBadge'

const COLORS = ['#7C3AED', '#22C55E', '#F59E0B', '#EF4444', '#3B82F6', '#C084FC']
const GENDER_COLORS: Record<string, string> = { Male: '#3B82F6', Female: '#DB2777', Other: '#C084FC' }
const AXIS_TICK = { fill: '#9494BD', fontSize: 12 }
const TOOLTIP_STYLE = { backgroundColor: 'rgba(20,20,42,0.9)', backdropFilter: 'blur(8px)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 10, color: '#ECECFC' }
const DAY = 86_400_000

function useDashboardStats() {
  return useQuery({
    queryKey: ['dashboard-stats'],
    queryFn: async () => {
      const [members, trainers, attendanceToday] = await Promise.all([
        supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'member'),
        supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'trainer'),
        supabase.from('attendance').select('id', { count: 'exact', head: true }).eq('check_in_date', new Date().toISOString().split('T')[0]),
      ])
      return {
        totalMembers: members.count ?? 0,
        totalTrainers: trainers.count ?? 0,
        attendanceToday: attendanceToday.count ?? 0,
      }
    },
  })
}

const MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

function getMonthOptions() {
  const options: { value: string; label: string }[] = []
  const now = new Date()
  for (let y = 2026; y <= now.getFullYear(); y++) {
    const maxM = y === now.getFullYear() ? now.getMonth() : 11
    for (let m = 0; m <= maxM; m++) {
      const d = new Date(y, m, 1)
      const value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
      options.push({ value, label: `${MONTH_NAMES[d.getMonth()]} ${d.getFullYear()}` })
    }
  }
  return options
}

function useAttendanceChart(yearMonth: string) {
  return useQuery({
    queryKey: ['attendance-chart', yearMonth],
    queryFn: async () => {
      const [year, month] = yearMonth.split('-').map(Number)
      const monthStart = new Date(year, month - 1, 1)
      const monthEnd = new Date(year, month, 0)
      const daysInMonth = monthEnd.getDate()

      const { data } = await supabase
        .from('attendance')
        .select('check_in_date')
        .gte('check_in_date', monthStart.toISOString().split('T')[0])
        .lte('check_in_date', monthEnd.toISOString().split('T')[0])

      const counts: Record<string, number> = {}
      if (data) {
        data.forEach(a => {
          counts[a.check_in_date] = (counts[a.check_in_date] || 0) + 1
        })
      }
      const days = []
      for (let i = 1; i <= daysInMonth; i++) {
        const key = `${year}-${String(month).padStart(2, '0')}-${String(i).padStart(2, '0')}`
        days.push({ date: key, count: counts[key] || 0 })
      }
      return days
    },
  })
}

function useGrowthData() {
  return useQuery({
    queryKey: ['dashboard-growth'],
    queryFn: async () => {
      const { data } = await supabase
        .from('profiles')
        .select('created_at')
        .eq('role', 'member')
        .order('created_at', { ascending: true })

      const monthly: Record<string, number> = {}
      data?.forEach(p => {
        const key = p.created_at?.slice(0, 7)
        if (key) monthly[key] = (monthly[key] || 0) + 1
      })
      let cumulative = 0
      return Object.entries(monthly).map(([month, count]) => {
        cumulative += count
        return { month, newMembers: count, totalMembers: cumulative }
      })
    },
  })
}

function useGenderData() {
  return useQuery({
    queryKey: ['dashboard-gender'],
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
}

function useTodaySessions() {
  return useQuery({
    queryKey: ['dashboard-today-sessions'],
    queryFn: async () => {
      const today = new Date().toISOString().split('T')[0]
      const { data } = await supabase
        .from('attendance')
        .select('*, profiles!attendance_member_id_fkey(full_name, code)')
        .eq('check_in_date', today)
        .order('check_in_time', { ascending: false })
        .limit(20)
      return data ?? []
    },
  })
}

function useExpiringMembers() {
  return useQuery({
    queryKey: ['dashboard-expiring'],
    queryFn: async () => {
      const { data } = await supabase
        .from('memberships')
        .select('id, member_id, plan_name, end_date, profiles!memberships_member_id_fkey(full_name, code)')
        .eq('status', 'active')
        .not('end_date', 'is', null)
        .not('plan_name', 'eq', 'Daily')
        .order('end_date', { ascending: true })
      const today = new Date()
      today.setHours(0, 0, 0, 0)
      const cutoff = today.getTime() + 7 * DAY
      return (data ?? [])
        .filter(m => {
          const end = new Date(m.end_date)
          const endDay = new Date(end.getFullYear(), end.getMonth(), end.getDate())
          return endDay.getTime() >= today.getTime() && endDay.getTime() <= cutoff
        })
        .slice(0, 10)
        .map(m => {
          const profiles = Array.isArray(m.profiles) ? m.profiles[0] : m.profiles
          const end = new Date(m.end_date)
          const endDay = new Date(end.getFullYear(), end.getMonth(), end.getDate()).getTime()
          return { ...m, profiles: profiles ?? null, daysLeft: Math.round((endDay - today.getTime()) / DAY) }
        })
    },
  })
}

const thCls = 'text-left px-4 py-3 text-[#55557A] text-xs uppercase tracking-wider border-b border-white/10'
const tdCls = 'px-4 py-3 text-sm'
const rowCls = 'border-b border-white/5 last:border-0'

export default function DashboardPage() {
  const { data: stats, isLoading } = useDashboardStats()

  const now = new Date()
  const defaultMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
  const [selectedMonth, setSelectedMonth] = useState(defaultMonth)
  const monthOptions = useMemo(() => getMonthOptions(), [])

  const { data: chartData } = useAttendanceChart(selectedMonth)
  const { data: growthData } = useGrowthData()
  const { data: genderData } = useGenderData()
  const { data: todaySessions } = useTodaySessions()
  const { data: expiring } = useExpiringMembers()

  const genderTotal = useMemo(() => (genderData ?? []).reduce((sum, d) => sum + d.value, 0), [genderData])

  if (isLoading) return <div className="text-center py-8 text-[#55557A]">Loading...</div>

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-[#ECECFC] display">Dashboard</h1>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 fade-up">
        <StatsCard title="Total Members" value={stats?.totalMembers ?? 0} icon={Users} />
        <StatsCard title="Total Trainers" value={stats?.totalTrainers ?? 0} icon={Dumbbell} />
        <StatsCard title="Attendance Today" value={stats?.attendanceToday ?? 0} icon={CalendarCheck} />
      </div>

      <div className="glass-card p-6 rounded-xl fade-up" style={{ animationDelay: '60ms' }}>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-[#ECECFC]">Daily Check-ins</h2>
          <select
            value={selectedMonth}
            onChange={e => setSelectedMonth(e.target.value)}
            className="px-3 py-1.5 glass-input border rounded-lg text-sm text-[#ECECFC] focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50 cursor-pointer"
          >
            {monthOptions.map(m => (
              <option key={m.value} value={m.value} className="bg-[#14142A]">{m.label}</option>
            ))}
          </select>
        </div>
        <div className="h-72">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" />
              <XAxis dataKey="date" tick={AXIS_TICK} interval={0} tickFormatter={v => `${new Date(v).getDate()}D`} />
              <YAxis tick={AXIS_TICK} label={{ value: 'Members', angle: -90, position: 'insideLeft', fill: '#55557A', fontSize: 12 }} />
              <Tooltip contentStyle={TOOLTIP_STYLE} labelStyle={{ color: '#B4B4D0' }} labelFormatter={v => new Date(v).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })} formatter={(value) => [`${value} member${value === 1 ? '' : 's'}`, 'Count']} />
              <Area type="monotone" dataKey="count" stroke="#3B82F6" fill="#3B82F6" fillOpacity={0.15} strokeWidth={2} />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 fade-up" style={{ animationDelay: '120ms' }}>
        <ChartCard title="Member Growth Over Time" icon={TrendingUp}>
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={growthData ?? []} margin={{ top: 12, right: 8, left: -8, bottom: 0 }}>
              <defs>
                <linearGradient id="growthTotal" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#7C3AED" stopOpacity={0.25} />
                  <stop offset="100%" stopColor="#7C3AED" stopOpacity={0} />
                </linearGradient>
                <linearGradient id="growthNew" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#22C55E" stopOpacity={0.2} />
                  <stop offset="100%" stopColor="#22C55E" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" vertical={false} />
              <XAxis dataKey="month" tick={AXIS_TICK} interval={0} tickFormatter={v => MONTH_NAMES[Number(v.split('-')[1]) - 1]} axisLine={{ stroke: 'rgba(255,255,255,0.08)' }} tickLine={false} />
              <YAxis tick={AXIS_TICK} axisLine={false} tickLine={false} />
              <Tooltip contentStyle={TOOLTIP_STYLE} labelStyle={{ color: '#B4B4D0' }} />
              <Area type="monotone" dataKey="totalMembers" stroke="#7C3AED" strokeWidth={2} fill="url(#growthTotal)" dot={{ fill: '#C084FC', r: 3 }} name="Total" />
              <Area type="monotone" dataKey="newMembers" stroke="#22C55E" strokeWidth={2} fill="url(#growthNew)" dot={{ fill: '#4ADE80', r: 3 }} name="New" />
            </AreaChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Gender Distribution" icon={Activity} isEmpty={genderTotal === 0} emptyMessage="No member profile data yet.">
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4 h-full">
            <div className="relative w-full sm:w-1/2 min-w-0 h-52 sm:h-full">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie data={genderData ?? []} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius="80%" innerRadius="55%" paddingAngle={3}>
                    {(genderData ?? []).map(d => (<Cell key={d.name} fill={GENDER_COLORS[d.name] ?? COLORS[0]} />))}
                  </Pie>
                  <Tooltip contentStyle={TOOLTIP_STYLE} />
                </PieChart>
              </ResponsiveContainer>
              <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
                <span className="text-2xl font-bold text-[#ECECFC] display">{genderTotal}</span>
                <span className="text-xs text-[#8888B3]">members</span>
              </div>
            </div>
            <div className="flex flex-col gap-3.5 shrink-0">
              {(genderData ?? []).map(d => (
                <div key={d.name} className="flex items-center gap-2.5">
                  <span className="w-3 h-3 rounded-full" style={{ backgroundColor: GENDER_COLORS[d.name] ?? COLORS[0] }} />
                  <span className="text-sm text-[#B4B4D0] w-14">{d.name}</span>
                  <span className="text-sm font-semibold text-[#ECECFC] w-8 text-right">{d.value}</span>
                  <span className="text-xs text-[#55557A] w-10 text-right">{genderTotal ? Math.round((d.value / genderTotal) * 100) : 0}%</span>
                </div>
              ))}
            </div>
          </div>
        </ChartCard>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 fade-up" style={{ animationDelay: '180ms' }}>
        <div className="glass-card p-6 rounded-xl">
          <h2 className="text-lg font-semibold text-[#ECECFC] mb-4">Today's Check-ins</h2>
          {(todaySessions ?? []).length === 0 ? (
            <p className="text-sm text-[#55557A]">No check-ins yet today</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr>
                    <th className={thCls}>Member</th>
                    <th className={thCls}>Time-in</th>
                    <th className={thCls}>Time-out</th>
                    <th className={thCls}>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {(todaySessions ?? []).map(s => {
                    const open = !s.check_out_time
                    return (
                      <tr key={s.id} className={rowCls}>
                        <td className={`${tdCls} text-[#ECECFC]`}>
                          {s.profiles?.full_name ?? 'Unknown'}
                          {s.profiles?.code ? <span className="text-[#55557A] text-xs ml-2">{s.profiles.code}</span> : null}
                        </td>
                        <td className={`${tdCls} text-[#B4B4D0]`}>{new Date(s.check_in_time).toLocaleTimeString()}</td>
                        <td className={`${tdCls} text-[#B4B4D0]`}>{open ? '—' : new Date(s.check_out_time).toLocaleTimeString()}</td>
                        <td className={`${tdCls}`}>
                          {open ? (
                            <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full bg-[#F59E0B]/15 text-[#FBBF24] text-xs font-medium">
                              Expires {new Date(s.expires_at).toLocaleTimeString()}
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full bg-[#22C55E]/15 text-[#4ADE80] text-xs font-medium">Done</span>
                          )}
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>

        <div className="glass-card p-6 rounded-xl">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-[#ECECFC]">Expiring Members</h2>
            <span className="text-xs text-[#55557A]">Next 7 days</span>
          </div>
          {(expiring ?? []).length === 0 ? (
            <p className="text-sm text-[#55557A]">No memberships expiring in the next 7 days</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr>
                    <th className={thCls}>Member</th>
                    <th className={thCls}>Plan</th>
                    <th className={thCls}>Ends</th>
                    <th className={thCls}>Days left</th>
                    <th className={`${thCls} text-right`}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {(expiring ?? []).map(m => (
                    <tr key={m.id} className={rowCls}>
                      <td className={`${tdCls} text-[#ECECFC]`}>
                        {m.profiles?.full_name ?? 'Unknown'}
                        {m.profiles?.code ? <span className="text-[#55557A] text-xs ml-2">{m.profiles.code}</span> : null}
                      </td>
                      <td className={`${tdCls} text-[#B4B4D0]`}>{m.plan_name}</td>
                      <td className={`${tdCls} text-[#B4B4D0] whitespace-nowrap`}>{new Date(m.end_date).toLocaleDateString()}</td>
                      <td className={`${tdCls}`}>
                        <StatusBadge status="expiring" />
                        <span className="text-[#55557A] text-xs ml-2">in {m.daysLeft}d</span>
                      </td>
                      <td className={`${tdCls} text-right`}>
                        <Link
                          to={`/members/${m.member_id}`}
                          className="inline-block px-3 py-1.5 text-xs font-medium rounded-lg bg-[#7C3AED]/15 text-[#C084FC] hover:bg-[#7C3AED]/25 focus-visible:ring-2 focus-visible:ring-[#7C3AED]/50 transition-colors"
                        >
                          Renew
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
