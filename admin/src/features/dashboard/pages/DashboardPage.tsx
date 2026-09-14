import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { supabase } from '@/lib/supabase'
import { Activity } from 'lucide-react'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  AreaChart, Area,
  PieChart, Pie, Cell,
} from 'recharts'
import StatsCard from '@/components/StatsCard'
import ChartCard from '@/components/ChartCard'

const COLORS = ['#7C3AED', '#22C55E', '#F59E0B', '#EF4444', '#3B82F6', '#C084FC']
const GENDER_COLORS: Record<string, string> = { Male: '#3B82F6', Female: '#DB2777', Other: '#C084FC' }
const STATUS_COLORS: Record<string, string> = { Active: '#22C55E', Inactive: '#EF4444' }
const AXIS_TICK = { fill: '#9494BD', fontSize: 11 }
const TOOLTIP_STYLE = { backgroundColor: 'rgba(20,20,42,0.9)', backdropFilter: 'blur(8px)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 10, color: '#ECECFC' }
const DAY = 86_400_000

function useDashboardStats() {
  return useQuery({
    queryKey: ['dashboard-stats'],
    queryFn: async () => {
      const [members, trainers, attendanceToday, revenue] = await Promise.all([
        supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'member'),
        supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'trainer'),
        supabase.from('attendance').select('id', { count: 'exact', head: true }).eq('check_in_date', new Date().toISOString().split('T')[0]),
        supabase.from('memberships').select('price').eq('status', 'active'),
      ])
      const totalRevenue = (revenue.data ?? []).reduce((sum, m) => sum + (Number(m.price) || 0), 0)
      return {
        totalMembers: members.count ?? 0,
        totalTrainers: trainers.count ?? 0,
        attendanceToday: attendanceToday.count ?? 0,
        totalRevenue,
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

function useRevenueChart(range: 'week' | 'month' | 'year') {
  return useQuery({
    queryKey: ['revenue-chart-v2', range],
    queryFn: async () => {
      const now = new Date()
      let start: Date
      let format: 'day' | 'month'

      if (range === 'week') {
        start = new Date(now.getTime() - 7 * DAY)
        format = 'day'
      } else if (range === 'month') {
        start = new Date(now.getTime() - 30 * DAY)
        format = 'day'
      } else {
        start = new Date(now.getFullYear(), 0, 1)
        format = 'month'
      }

      const { data } = await supabase
        .from('memberships')
        .select('start_date, price')
        .gte('start_date', start.toISOString().split('T')[0])

      const map: Record<string, number> = {}
      (data ?? []).forEach(m => {
        const d = new Date(m.start_date)
        let key: string
        if (format === 'day') {
          key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
        } else {
          key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
        }
        map[key] = (map[key] || 0) + (Number(m.price) || 0)
      })

      return Object.entries(map)
        .map(([date, revenue]) => ({ date, revenue: Math.round(revenue) }))
        .sort((a, b) => a.date.localeCompare(b.date))
    },
  })
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

function useGenderAndActivityData() {
  return useQuery({
    queryKey: ['dashboard-gender-activity'],
    queryFn: async () => {
      const sevenDaysAgo = new Date(Date.now() - 7 * DAY).toISOString().split('T')[0]
      const { data: profiles } = await supabase.from('profiles').select('id, gender').eq('role', 'member')

      const memberIds = (profiles ?? []).map(p => p.id)
      let recentAttendance: string[] = []
      if (memberIds.length > 0) {
        const { data } = await supabase
          .from('attendance')
          .select('member_id')
          .in('member_id', memberIds)
          .gte('check_in_date', sevenDaysAgo)
        recentAttendance = [...new Set((data ?? []).map(a => a.member_id))]
      }

      const activeIds = new Set(recentAttendance)
      const m = (profiles ?? []).filter(p => p.gender === 'male').length
      const f = (profiles ?? []).filter(p => p.gender === 'female').length
      const o = (profiles ?? []).filter(p => p.gender && !['male', 'female'].includes(p.gender)).length
      const active = (profiles ?? []).filter(p => activeIds.has(p.id)).length
      const inactive = (profiles ?? []).length - active

      return [
        { name: 'Male', value: m, type: 'gender' },
        { name: 'Female', value: f, type: 'gender' },
        { name: 'Other', value: o, type: 'gender' },
        { name: 'Active', value: active, type: 'status' },
        { name: 'Inactive', value: inactive, type: 'status' },
      ].filter(d => d.value > 0)
    },
  })
}

function useRecentActivity() {
  return useQuery({
    queryKey: ['recent-activity'],
    queryFn: async () => {
      const sevenDaysAgo = new Date(Date.now() - 7 * DAY).toISOString().split('T')[0]
      const today = new Date().toISOString().split('T')[0]

      const [attendanceRes, assignmentRes, expiringRes, feedbackRes, dailyMembersRes] = await Promise.all([
        supabase.from('attendance').select('id, member_id, check_in_time, profiles!attendance_member_id_fkey(full_name, code)').order('check_in_time', { ascending: false }).limit(10),
        supabase.from('trainer_assignments').select('id, trainer_id, member_id, assigned_at, profiles!trainer_assignments_trainer_id_fkey(full_name), profiles!trainer_assignments_member_id_fkey(full_name)').order('assigned_at', { ascending: false }).limit(10),
        supabase.from('memberships').select('id, member_id, plan_name, end_date, profiles!memberships_member_id_fkey(full_name, code)').eq('status', 'active').not('end_date', 'is', null).lte('end_date', new Date(Date.now() + 7 * DAY).toISOString().split('T')[0]).order('end_date', { ascending: true }).limit(10),
        supabase.from('trainer_feedback').select('id, member_id, content, created_at, profiles!trainer_feedback_member_id_fkey(full_name)').order('created_at', { ascending: false }).limit(10),
        supabase.from('memberships').select('member_id').eq('plan_name', 'Daily').eq('status', 'active'),
      ])

      const dailyMemberIds = new Set((dailyMembersRes.data ?? []).map(m => m.member_id))
      let inactiveMembers: { member_id: string; full_name: string; code: string | null; daysInactive: number }[] = []

      if (dailyMemberIds.size > 0) {
        const { data: attendanceData } = await supabase
          .from('attendance')
          .select('member_id, check_in_date')
          .in('member_id', Array.from(dailyMemberIds))
          .order('check_in_date', { ascending: false })

        const lastCheckIn: Record<string, string> = {}
        attendanceData?.forEach(a => {
          if (!lastCheckIn[a.member_id] || a.check_in_date > lastCheckIn[a.member_id]) {
            lastCheckIn[a.member_id] = a.check_in_date
          }
        })

        const now = new Date()
        now.setHours(0, 0, 0, 0)
        const memberIds = Array.from(dailyMemberIds)
        let profileMap: Record<string, { full_name: string; code: string }> = {}
        if (memberIds.length > 0) {
          const { data: profiles } = await supabase
            .from('profiles')
            .select('id, full_name, code')
            .in('id', memberIds)
          profiles?.forEach(p => { profileMap[p.id] = p })
        }

        inactiveMembers = (dailyMembersRes.data ?? [])
          .map(m => {
            const last = lastCheckIn[m.member_id]
            const daysInactive = last ? Math.floor((now.getTime() - new Date(last).getTime()) / DAY) : 999
            return {
              member_id: m.member_id,
              full_name: profileMap[m.member_id]?.full_name ?? 'Unknown',
              code: profileMap[m.member_id]?.code,
              daysInactive,
            }
          })
          .filter(r => r.daysInactive >= 7)
          .sort((a, b) => b.daysInactive - a.daysInactive)
          .slice(0, 10)
      }

      const activities: { id: string; type: string; message: string; timestamp: string; userName: string; userCode?: string }[] = []

      ;(attendanceRes.data ?? []).forEach(a => {
        const profile = Array.isArray(a.profiles) ? a.profiles[0] : a.profiles
        activities.push({
          id: `checkin-${a.id}`,
          type: 'checkin',
          message: 'Checked in',
          timestamp: a.check_in_time,
          userName: profile?.full_name ?? 'Unknown',
          userCode: profile?.code,
        })
      })

      ;(assignmentRes.data ?? []).forEach(a => {
        const trainer = Array.isArray(a.profiles) ? a.profiles[0] : a.profiles
        const member = Array.isArray(a.profiles) ? a.profiles[1] : null
        activities.push({
          id: `assign-${a.id}`,
          type: 'trainer',
          message: `Assigned to ${trainer?.full_name ?? 'trainer'}`,
          timestamp: a.assigned_at,
          userName: member?.full_name ?? 'Unknown',
          userCode: member?.code,
        })
      })

      ;(expiringRes.data ?? []).forEach(m => {
        const profile = Array.isArray(m.profiles) ? m.profiles[0] : m.profiles
        const daysLeft = Math.ceil((new Date(m.end_date).getTime() - Date.now()) / DAY)
        activities.push({
          id: `expire-${m.id}`,
          type: 'expiring',
          message: `Membership expires in ${daysLeft} days`,
          timestamp: m.end_date,
          userName: profile?.full_name ?? 'Unknown',
          userCode: profile?.code,
        })
      })

      ;(feedbackRes.data ?? []).forEach(f => {
        const profile = Array.isArray(f.profiles) ? f.profiles[0] : f.profiles
        activities.push({
          id: `feedback-${f.id}`,
          type: 'feedback',
          message: `New feedback: "${f.content.slice(0, 50)}${f.content.length > 50 ? '...' : ''}"`,
          timestamp: f.created_at,
          userName: profile?.full_name ?? 'Unknown',
        })
      })

      inactiveMembers.forEach(m => {
        activities.push({
          id: `inactive-${m.member_id}`,
          type: 'inactive',
          message: `Inactive for ${m.daysInactive} days`,
          timestamp: new Date(Date.now() - m.daysInactive * DAY).toISOString(),
          userName: m.full_name,
          userCode: m.code,
        })
      })

      return activities
        .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
        .slice(0, 20)
    },
  })
}

const thCls = 'text-left px-3 py-2 text-[#55557A] text-xs uppercase tracking-wider border-b border-white/10'
const tdCls = 'px-3 py-2 text-sm'
const rowCls = 'border-b border-white/5 last:border-0'

const ACTIVITY_STYLES: Record<string, { bg: string; text: string; label: string }> = {
  checkin: { bg: 'bg-[#22C55E]/15', text: 'text-[#4ADE80]', label: 'Check-in' },
  trainer: { bg: 'bg-[#3B82F6]/15', text: 'text-[#60A5FA]', label: 'Trainer' },
  expiring: { bg: 'bg-[#F59E0B]/15', text: 'text-[#FBBF24]', label: 'Expiring' },
  inactive: { bg: 'bg-[#EF4444]/15', text: 'text-[#EF4444]', label: 'Inactive' },
  feedback: { bg: 'bg-[#7C3AED]/15', text: 'text-[#C084FC]', label: 'Feedback' },
}

export default function DashboardPage() {
  const { data: stats, isLoading } = useDashboardStats()

  const now = new Date()
  const defaultMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
  const [selectedMonth, setSelectedMonth] = useState(defaultMonth)
  const [revenueRange, setRevenueRange] = useState<'week' | 'month' | 'year'>('week')
  const monthOptions = useMemo(() => getMonthOptions(), [])

  const { data: chartData } = useAttendanceChart(selectedMonth)
  const { data: growthData } = useGrowthData()
  const { data: genderActivityData } = useGenderAndActivityData()
  const { data: recentActivity } = useRecentActivity()
  const { data: revenueData } = useRevenueChart(revenueRange)

  const memberTrend = useMemo(() => {
    if (!stats?.totalMembers || !growthData || growthData.length < 2) return undefined
    const current = growthData[growthData.length - 1].totalMembers
    const previous = growthData[growthData.length - 2].totalMembers
    if (previous === 0) return undefined
    return Math.round(((current - previous) / previous) * 100)
  }, [stats, growthData])

  const trainerTrend = useMemo(() => {
    if (!stats?.totalTrainers || !growthData || growthData.length < 2) return undefined
    const current = growthData[growthData.length - 1].newMembers
    const previous = growthData[growthData.length - 2].newMembers
    if (previous === 0) return undefined
    return Math.round(((current - previous) / previous) * 100)
  }, [stats, growthData])

  const genderTotal = useMemo(() => (genderActivityData ?? []).filter(d => d.type === 'gender').reduce((sum, d) => sum + d.value, 0), [genderActivityData])
  const activeCount = useMemo(() => (genderActivityData ?? []).find(d => d.name === 'Active')?.value ?? 0, [genderActivityData])
  const inactiveCount = useMemo(() => (genderActivityData ?? []).find(d => d.name === 'Inactive')?.value ?? 0, [genderActivityData])

  const totalRevenue = useMemo(() => {
    if (!revenueData || revenueData.length === 0) return 0
    return revenueData.reduce((sum, d) => sum + d.revenue, 0)
  }, [revenueData])

  const revenueChartData = useMemo(() => {
    if (!revenueData) return []
    if (revenueRange === 'year') {
      const monthMap: Record<string, { date: string; revenue: number }> = {}
      revenueData.forEach(d => {
        const monthKey = d.date.slice(0, 7)
        if (!monthMap[monthKey]) monthMap[monthKey] = { date: monthKey, revenue: 0 }
        monthMap[monthKey].revenue += d.revenue
      })
      return Object.values(monthMap).sort((a, b) => a.date.localeCompare(b.date))
    }
    return revenueData
  }, [revenueData, revenueRange])

  const revenueXFormatter = (v: string) => {
    if (revenueRange === 'year') {
      const [y, m] = v.split('-')
      return MONTH_NAMES[Number(m) - 1] || v
    }
    const d = new Date(v)
    return `${d.getMonth() + 1}/${d.getDate()}`
  }

  if (isLoading) return <div className="text-center py-8 text-[#55557A]">Loading...</div>

  return (
    <div className="h-full flex flex-col gap-2.5">
      <div className="grid grid-cols-4 gap-3">
        <StatsCard
          title="Total Revenue"
          value={stats?.totalRevenue ?? 0}
          trend={undefined}
          sparkData={revenueChartData?.slice(-10).map(d => ({ value: d.revenue }))}
          variant="emerald"
          sparkColor="#10B981"
        />
        <StatsCard
          title="Total Members"
          value={stats?.totalMembers ?? 0}
          trend={memberTrend ? { value: memberTrend, label: 'from last month' } : undefined}
          sparkData={growthData?.slice(-10).map(d => ({ value: d.totalMembers }))}
          variant="purple"
          sparkColor="#7C3AED"
        />
        <StatsCard
          title="Total Trainers"
          value={stats?.totalTrainers ?? 0}
          trend={trainerTrend ? { value: trainerTrend, label: 'from last month' } : undefined}
          sparkData={growthData?.slice(-10).map(d => ({ value: d.newMembers }))}
          variant="blue"
          sparkColor="#3B82F6"
        />
        <StatsCard
          title="Attendance Today"
          value={stats?.attendanceToday ?? 0}
          trend={{ value: 0, label: 'from yesterday' }}
          sparkData={chartData?.slice(-10).map(d => ({ value: d.count }))}
          variant="green"
          sparkColor="#22C55E"
        />
      </div>

      <div className="grid grid-cols-12 gap-3 min-h-0">
        <div className="col-span-7 flex flex-col gap-3">
          <div className="glass-card rounded-[12px] border border-white/10 shadow-sm flex flex-col min-h-0 flex-1">
            <div className="flex items-center justify-between px-4 pt-3 pb-2">
              <h2 className="text-[13px] font-semibold text-[#ECECFC]">Daily Check-ins</h2>
              <select
                value={selectedMonth}
                onChange={e => setSelectedMonth(e.target.value)}
                className="px-2 py-1 text-xs rounded-md bg-white/[0.08] border border-white/10 text-[#ECECFC] focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50 cursor-pointer"
              >
                {monthOptions.map(m => (
                  <option key={m.value} value={m.value} className="bg-[#14142A]">{m.label}</option>
                ))}
              </select>
            </div>
            <div className="px-2 pb-2 flex-1 min-h-0">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={chartData ?? []}>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" vertical={false} />
                  <XAxis
                    dataKey="date"
                    tick={AXIS_TICK}
                    tickCount={7}
                    tickFormatter={v => `${new Date(v).getDate()}`}
                    axisLine={{ stroke: 'rgba(255,255,255,0.06)' }}
                    tickLine={false}
                  />
                  <YAxis tick={AXIS_TICK} axisLine={false} tickLine={false} width={28} />
                  <Tooltip
                    contentStyle={TOOLTIP_STYLE}
                    labelStyle={{ color: '#B4B4D0' }}
                    labelFormatter={v => {
                      const d = new Date(v)
                      return `Day ${d.getDate()}`
                    }}
                    formatter={(value: number) => [`${value}`, 'Check-ins']}
                  />
                  <Bar dataKey="count" fill="#7C3AED" radius={[3, 3, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>

          <div className="glass-card rounded-[12px] border border-white/10 shadow-sm flex flex-col min-h-0 flex-1">
            <div className="flex items-center justify-between px-4 pt-3 pb-2">
              <h2 className="text-[13px] font-semibold text-[#ECECFC]">Revenue Overview</h2>
              <div className="flex items-center gap-1 rounded-lg bg-white/[0.08] p-0.5">
                {(['week', 'month', 'year'] as const).map(r => (
                  <button
                    key={r}
                    onClick={() => setRevenueRange(r)}
                    className={`px-2.5 py-1 text-[11px] font-medium rounded-md transition-colors capitalize ${
                      revenueRange === r
                        ? 'bg-[#7C3AED] text-white shadow-[0_0_10px_rgba(124,58,237,0.35)]'
                        : 'text-[#8A8AB0] hover:text-white'
                    }`}
                  >
                    {r === 'week' ? 'This Week' : r === 'month' ? 'This Month' : 'This Year'}
                  </button>
                ))}
              </div>
            </div>
            <div className="px-2 pb-2 flex-1 min-h-0">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={revenueChartData ?? []} margin={{ top: 0, right: 8, left: -8, bottom: 0 }}>
                  <defs>
                    <linearGradient id="revenueGradient" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#7C3AED" stopOpacity={0.3} />
                      <stop offset="100%" stopColor="#7C3AED" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" vertical={false} />
                  <XAxis
                    dataKey="date"
                    tick={AXIS_TICK}
                    tickCount={7}
                    tickFormatter={v => revenueXFormatter(v)}
                    axisLine={{ stroke: 'rgba(255,255,255,0.06)' }}
                    tickLine={false}
                  />
                  <YAxis tick={AXIS_TICK} axisLine={false} tickLine={false} width={28} tickFormatter={v => `₱${v}`} />
                  <Tooltip
                    contentStyle={TOOLTIP_STYLE}
                    labelStyle={{ color: '#B4B4D0' }}
                    labelFormatter={v => revenueRange === 'year' ? v : new Date(v).toLocaleDateString()}
                    formatter={(value: number) => [`₱${value.toLocaleString()}`, 'Revenue']}
                  />
                  <Area type="monotone" dataKey="revenue" stroke="#7C3AED" strokeWidth={2} fill="url(#revenueGradient)" dot={{ fill: '#C084FC', r: 2 }} name="Revenue" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>

          <div className="glass-card rounded-[12px] border border-white/10 shadow-sm flex flex-col min-h-0 flex-1">
            <div className="flex items-center justify-between px-4 pt-3 pb-2">
              <h2 className="text-[13px] font-semibold text-[#ECECFC]">Member Growth Over Time</h2>
              <div className="flex items-center gap-3 text-[11px] text-[#7A7AA0]">
                <span className="inline-flex items-center gap-1.5"><span className="w-1.5 h-1.5 rounded-full bg-[#7C3AED]" /> Total</span>
                <span className="inline-flex items-center gap-1.5"><span className="w-1.5 h-1.5 rounded-full bg-[#22C55E]" /> New</span>
              </div>
            </div>
            <div className="px-2 pb-2 flex-1 min-h-0">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={growthData ?? []} margin={{ top: 0, right: 8, left: -8, bottom: 0 }}>
                  <defs>
                    <linearGradient id="growthTotal" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#7C3AED" stopOpacity={0.3} />
                      <stop offset="100%" stopColor="#7C3AED" stopOpacity={0} />
                    </linearGradient>
                    <linearGradient id="growthNew" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#22C55E" stopOpacity={0.25} />
                      <stop offset="100%" stopColor="#22C55E" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" vertical={false} />
                  <XAxis dataKey="month" tick={AXIS_TICK} interval={0} tickFormatter={v => MONTH_NAMES[Number(v.split('-')[1]) - 1]} axisLine={{ stroke: 'rgba(255,255,255,0.06)' }} tickLine={false} />
                  <YAxis tick={AXIS_TICK} axisLine={false} tickLine={false} width={28} />
                  <Tooltip contentStyle={TOOLTIP_STYLE} labelStyle={{ color: '#B4B4D0' }} />
                  <Area type="monotone" dataKey="totalMembers" stroke="#7C3AED" strokeWidth={2} fill="url(#growthTotal)" dot={{ fill: '#C084FC', r: 2 }} name="Total Members" />
                  <Area type="monotone" dataKey="newMembers" stroke="#22C55E" strokeWidth={2} fill="url(#growthNew)" dot={{ fill: '#4ADE80', r: 2 }} name="New Members" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>
        </div>

        <div className="col-span-5 flex flex-col gap-3 min-h-0">
          <div className="glass-card rounded-[12px] border border-white/10 shadow-sm flex flex-col min-h-0">
            <h2 className="text-[13px] font-semibold text-[#ECECFC] px-4 pt-3 pb-2">Member Overview</h2>
            <div className="flex items-center gap-4 px-4 pb-3">
              <div className="relative w-[110px] h-[110px] shrink-0">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie data={genderActivityData ?? []} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius="80%" innerRadius="55%" paddingAngle={3}>
                      {(genderActivityData ?? []).map(d => (
                        <Cell key={d.name} fill={d.type === 'status' ? (STATUS_COLORS[d.name] || COLORS[0]) : (GENDER_COLORS[d.name] || COLORS[0])} />
                      ))}
                    </Pie>
                    <Tooltip contentStyle={TOOLTIP_STYLE} />
                  </PieChart>
                </ResponsiveContainer>
                <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
                  <span className="text-base font-bold text-[#ECECFC] display">{genderTotal + activeCount + inactiveCount}</span>
                  <span className="text-[10px] text-[#8888B3]">Members</span>
                </div>
              </div>
              <div className="flex flex-col gap-2 flex-1">
                {(genderActivityData ?? []).map(d => {
                  const total = genderTotal + activeCount + inactiveCount
                  const pct = total ? Math.round((d.value / total) * 100) : 0
                  return (
                    <div key={d.name} className="flex items-center gap-2">
                      <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: d.type === 'status' ? (STATUS_COLORS[d.name] || COLORS[0]) : (GENDER_COLORS[d.name] || COLORS[0]) }} />
                      <span className="text-xs text-[#B4B4D0] w-14">{d.name}</span>
                      <span className="text-xs font-semibold text-[#ECECFC]">{d.value}</span>
                      <div className="flex-1 h-1.5 rounded-full bg-white/10">
                        <div className="h-full rounded-full" style={{ width: `${pct}%`, backgroundColor: d.type === 'status' ? (STATUS_COLORS[d.name] || COLORS[0]) : (GENDER_COLORS[d.name] || COLORS[0]) }} />
                      </div>
                      <span className="text-[11px] text-[#55557A] w-8 text-right">{pct}%</span>
                    </div>
                  )
                })}
              </div>
            </div>
          </div>

          <div className="glass-card rounded-[12px] border border-white/10 shadow-sm flex flex-col min-h-0 flex-1">
            <div className="flex items-center justify-between px-4 pt-3 pb-2">
              <h2 className="text-[13px] font-semibold text-[#ECECFC]">Recent Activity</h2>
              <span className="text-[11px] text-[#7A7AA0]">{(recentActivity ?? []).length}</span>
            </div>
            <div className="overflow-y-auto flex-1 min-h-0">
              {(recentActivity ?? []).length === 0 ? (
                <div className="flex-1 flex flex-col items-center justify-center gap-1.5 px-4 py-6 text-center">
                  <Activity className="w-4 h-4 text-[#5A5A82]" strokeWidth={1.75} />
                  <p className="text-[13px] text-[#8888B3]">No recent activity</p>
                </div>
              ) : (
                <div className="flex flex-col gap-1">
                  {(recentActivity ?? []).map(a => {
                    const style = ACTIVITY_STYLES[a.type] || ACTIVITY_STYLES.checkin
                    const time = new Date(a.timestamp)
                    const timeStr = time.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
                    const dateStr = time.toLocaleDateString([], { month: 'short', day: 'numeric' })
                    return (
                      <div key={a.id} className="flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-white/[0.03] transition-colors">
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-medium ${style.bg} ${style.text}`}>
                          {style.label}
                        </span>
                        <div className="flex-1 min-w-0">
                          <p className="text-xs text-[#ECECFC] truncate">{a.userName} {a.userCode && <span className="text-[#55557A] ml-1">{a.userCode}</span>}</p>
                          <p className="text-[11px] text-[#55557A] truncate">{a.message}</p>
                        </div>
                        <span className="text-[10px] text-[#55557A] whitespace-nowrap">{dateStr} {timeStr}</span>
                      </div>
                    )
                  })}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
