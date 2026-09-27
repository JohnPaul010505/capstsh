import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { ClipboardList, LineChart as TrendIcon, UserPlus, Users, Wallet } from 'lucide-react'
import StatsCard from '@/components/StatsCard'
import { supabase } from '@/lib/supabase'
import DashboardTabs, { type TabDef } from '@/features/dashboard/components/DashboardTabs'
import CheckinsTab from '@/features/dashboard/panels/CheckinsTab'
import RevenueTab from '@/features/dashboard/panels/RevenueTab'
import GrowthTab from '@/features/dashboard/panels/GrowthTab'
import MemberOverviewTab from '@/features/dashboard/panels/MemberOverviewTab'
import ActivityTab from '@/features/dashboard/panels/ActivityTab'
import { autoGrain, lastNDays, parseDay, type Grain, type Range } from '@/features/dashboard/lib/dateRange'
import type { PlanFilter } from '@/features/dashboard/lib/planFilter'
import type { ActivityType } from '@/features/dashboard/lib/activityFeed'
import { useCheckinsTab } from '@/features/dashboard/hooks/useCheckinsTab'

const TABS: TabDef[] = [
  { id: 'checkins', label: 'Daily Check-ins', icon: ClipboardList },
  { id: 'revenue', label: 'Revenue Overview', icon: Wallet },
  { id: 'growth', label: 'Member Growth', icon: UserPlus },
  { id: 'members', label: 'Member Overview', icon: Users },
  { id: 'activity', label: 'Recent Activity', icon: TrendIcon },
]

/** All-time totals behind the summary row (not range filtered by design). */
function useDashboardBaseStats() {
  return useQuery({
    queryKey: ['dashboard-base-stats'],
    queryFn: async () => {
      const [members, trainers, revenue] = await Promise.all([
        supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'member'),
        supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'trainer'),
        supabase.from('memberships').select('price').eq('status', 'active'),
      ])
      const totalRevenue = (revenue.data ?? []).reduce((sum, m) => sum + (Number(m.price) || 0), 0)
      return { totalMembers: members.count ?? 0, totalTrainers: trainers.count ?? 0, totalRevenue }
    },
  })
}

/** Month-over-month revenue for the Total Revenue card (trend + sparkline). */
function useRevenueMonthlySummary() {
  return useQuery({
    queryKey: ['revenue-monthly-summary'],
    queryFn: async () => {
      const now = new Date()
      const { data } = await supabase.from('memberships').select('start_date, created_at, price').eq('status', 'active')

      const monthly: Record<string, number> = {}
      ;(data ?? []).forEach(m => {
        const rawDate = m.start_date || m.created_at
        if (!rawDate) return
        // Local parse — 'YYYY-MM-DD' via new Date() is UTC and shifts the month in PH.
        const d = parseDay(rawDate.slice(0, 10))
        const monthKey = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
        monthly[monthKey] = (monthly[monthKey] || 0) + (Number(m.price) || 0)
      })

      // Dense rolling 12-month series so the card sparkline always has a line.
      const series: { value: number }[] = []
      for (let i = 11; i >= 0; i--) {
        const d = new Date(now.getFullYear(), now.getMonth() - i, 1)
        const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
        series.push({ value: Math.round(monthly[key] || 0) })
      }
      return { thisMonthRevenue: series[11].value, lastMonthRevenue: series[10].value, series }
    },
  })
}

/** Member/trainer counts by join month — sparklines for the summary row. */
function useGrowthData() {
  return useQuery({
    queryKey: ['dashboard-growth'],
    queryFn: async () => {
      const { data } = await supabase
        .from('profiles')
        .select('created_at, role')
        .in('role', ['member', 'trainer'])
        .order('created_at', { ascending: true })

      const memberMonthly: Record<string, number> = {}
      const trainerMonthly: Record<string, number> = {}
      ;(data ?? []).forEach(p => {
        if (!p.created_at) return
        const d = parseDay(p.created_at.slice(0, 10))
        const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
        const bucket = p.role === 'trainer' ? trainerMonthly : memberMonthly
        bucket[key] = (bucket[key] || 0) + 1
      })

      let memberTotal = 0
      let trainerTotal = 0
      const now = new Date()
      const months: { key: string; memberTotal: number; trainerTotal: number }[] = []
      for (let i = 11; i >= 0; i--) {
        const d = new Date(now.getFullYear(), now.getMonth() - i, 1)
        const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
        memberTotal += memberMonthly[key] || 0
        trainerTotal += trainerMonthly[key] || 0
        months.push({ key, memberTotal, trainerTotal })
      }
      return months
    },
  })
}

/**
 * Admin dashboard root: one screen, five tabbed sub-pages.
 *
 * Filter state (range / membership type / chart granularity / activity type)
 * lives HERE so it survives tab switches; each active panel refetches through
 * query keys built from it. Only the active panel mounts — the others' queries
 * stay cached by React Query, so switching back is instant.
 */
export default function DashboardPage() {
  const [range, setRange] = useState<Range>(() => lastNDays(90))
  const [plan, setPlan] = useState<PlanFilter>('all')
  const [grainOverride, setGrainOverride] = useState<Grain | undefined>(undefined)
  const [activityType, setActivityType] = useState<ActivityType | 'all'>('all')
  const [tab, setTab] = useState<string>(TABS[0].id)

  // A new span gets fresh automatic granularity; the override only applies to
  // the range it was chosen for.
  const grain: Grain = grainOverride ?? autoGrain(range)
  const onRangeChange = (r: Range) => {
    setRange(r)
    setGrainOverride(undefined)
  }

  const { data: baseStats } = useDashboardBaseStats()
  const { data: revenueSummary } = useRevenueMonthlySummary()
  const { data: growthMonths } = useGrowthData()

  // Shared with the Daily Check-ins panel (same query key → single fetch);
  // powers the summary row's Total Attendance card, which is range + type
  // filtered and deliberately shows NO percentage.
  const attendance = useCheckinsTab(range, plan, grain)

  const revenueTrend = useMemo(() => {
    if (!revenueSummary) return undefined
    const { thisMonthRevenue, lastMonthRevenue } = revenueSummary
    if (lastMonthRevenue === 0 && thisMonthRevenue === 0) return undefined
    if (lastMonthRevenue === 0) return undefined
    return Math.round(((thisMonthRevenue - lastMonthRevenue) / lastMonthRevenue) * 100)
  }, [revenueSummary])

  const memberTrend = useMemo(() => {
    if (!growthMonths || growthMonths.length < 2) return undefined
    const cur = growthMonths[growthMonths.length - 1].memberTotal
    const prev = growthMonths[growthMonths.length - 2].memberTotal
    if (prev === 0) return undefined
    return Math.round(((cur - prev) / prev) * 100)
  }, [growthMonths])

  const trainerTrend = useMemo(() => {
    if (!growthMonths || growthMonths.length < 2) return undefined
    const cur = growthMonths[growthMonths.length - 1].trainerTotal
    const prev = growthMonths[growthMonths.length - 2].trainerTotal
    if (prev === 0) return undefined
    return Math.round(((cur - prev) / prev) * 100)
  }, [growthMonths])

  const panelProps = { range, onRangeChange, plan, onPlanChange: setPlan, grain, onGrainChange: setGrainOverride }
  const attendanceSpark = attendance.points.slice(-10).map(p => ({ value: p.count }))

  return (
    <div className="h-full flex flex-col gap-3">
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-3">
        <StatsCard
          title="Total Revenue"
          value={baseStats?.totalRevenue ?? 0}
          trend={revenueTrend !== undefined ? { value: revenueTrend, label: 'from last month' } : undefined}
          sparkData={revenueSummary?.series.slice(-10)}
          iconVariant="purple"
          sparkColor="#10B981"
        />
        <StatsCard
          title="Total Members"
          value={baseStats?.totalMembers ?? 0}
          trend={memberTrend !== undefined ? { value: memberTrend, label: 'from last month' } : undefined}
          sparkData={growthMonths?.map(m => ({ value: m.memberTotal }))}
          iconVariant="purple"
          sparkColor="#7C3AED"
        />
        <StatsCard
          title="Total Trainers"
          value={baseStats?.totalTrainers ?? 0}
          trend={trainerTrend !== undefined ? { value: trainerTrend, label: 'from last month' } : undefined}
          sparkData={growthMonths?.map(m => ({ value: m.trainerTotal }))}
          iconVariant="blue"
          sparkColor="#3B82F6"
        />
        <StatsCard
          title="Total Attendance"
          value={attendance.total}
          sparkData={attendanceSpark.length > 1 ? attendanceSpark : undefined}
          iconVariant="green"
          sparkColor="#22C55E"
        />
      </div>

      <DashboardTabs tabs={TABS} value={tab} onChange={setTab} />

      <div
        role="tabpanel"
        id={`dash-panel-${tab}`}
        aria-labelledby={`dash-tab-${tab}`}
        tabIndex={0}
        className="flex-1 min-h-0 overflow-y-auto pr-1 focus:outline-none"
      >
        <div className="flex flex-col gap-4 pb-2">
          {tab === 'checkins' && <CheckinsTab {...panelProps} />}
          {tab === 'revenue' && <RevenueTab {...panelProps} />}
          {tab === 'growth' && <GrowthTab {...panelProps} />}
          {tab === 'members' && <MemberOverviewTab {...panelProps} />}
          {tab === 'activity' && (
            <ActivityTab {...panelProps} activityType={activityType} onActivityTypeChange={setActivityType} />
          )}
        </div>
      </div>
    </div>
  )
}

