import { useState } from 'react'
import { Activity as ActivityIcon, CalendarDays, Crown, UserPlus } from 'lucide-react'
import KpiCard from '@/components/KpiCard'
import RecordsTable, { type RecordsColumn } from '@/components/RecordsTable'
import Badge from '@/components/Badge'
import TabHeader, { PLAN_FILTER_OPTIONS, type TabPanelProps } from '@/features/dashboard/components/TabHeader'
import TrendChartCard from '@/features/dashboard/components/TrendChartCard'
import { DualLineTrend } from '@/features/dashboard/components/TrendCharts'
import { fmtDay, formatRangeLabel } from '@/features/dashboard/lib/dateRange'
import type { PlanFilter } from '@/features/dashboard/lib/planFilter'
import { useGrowthTab, type GrowthRecord } from '@/features/dashboard/hooks/useGrowthTab'

export default function GrowthTab(props: TabPanelProps) {
  const { range, onRangeChange, plan, onPlanChange, grain, onGrainChange } = props
  const { totalNew, avg, days, peakDay, peakCount, activeCount, points, records, isLoading } =
    useGrowthTab(range, plan, grain)
  const [search, setSearch] = useState('')

  const columns: RecordsColumn<GrowthRecord>[] = [
    {
      key: 'when',
      header: 'Date & Time',
      render: r => (
        <div className="leading-tight">
          <span className="text-fg-strong">{fmtDay(r.day)}</span>
          <span className="ml-2 text-[12px] text-fg-muted">{new Date(r.createdAt).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}</span>
        </div>
      ),
    },
    { key: 'name', header: 'Member Name', render: r => <span className="font-medium text-fg-strong">{r.memberName}</span> },
    { key: 'code', header: 'Member ID', render: r => <span className="font-mono text-[12px] text-fg-muted">{r.memberCode ?? '—'}</span> },
    { key: 'plan', header: 'Membership Type', render: r => <Badge tone="purple">{r.planName}</Badge> },
    { key: 'status', header: 'Status', render: r => <Badge tone={r.status === 'Active' ? 'green' : 'muted'}>{r.status}</Badge> },
  ]

  const chartPoints = points.map(p => ({ key: p.key, label: p.label, full: p.full, value: p.value, total: p.total }))
  const hasData = chartPoints.some(p => p.value > 0 || p.total > 0)

  return (
    <div className="flex flex-col gap-3.5">
      <TabHeader
        title="Member Growth"
        subtitle="New members who joined inside the selected window, with the running membership total underneath."
        range={range}
        onRangeChange={onRangeChange}
        filter={{
          options: PLAN_FILTER_OPTIONS,
          value: plan === 'all' ? '' : plan,
          onChange: v => onPlanChange((v || 'all') as PlanFilter),
          placeholder: 'All Membership Types',
        }}
      />

      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-3">
        <KpiCard title="Total New Members" value={totalNew.toLocaleString()} sub={formatRangeLabel(range)} icon={UserPlus} tone="purple" />
        <KpiCard title="Daily Average" value={avg.toFixed(1)} sub={`${days} day${days === 1 ? '' : 's'} in range`} icon={ActivityIcon} tone="blue" />
        <KpiCard
          title="Highest Growth Day"
          value={peakCount > 0 ? peakCount.toLocaleString() : '0'}
          sub={peakDay ? `${fmtDay(peakDay)} · new members` : 'No growth in range'}
          icon={CalendarDays}
          tone="amber"
        />
        <KpiCard title="Active in Range" value={activeCount.toLocaleString()} sub="members with at least one visit" icon={Crown} tone="green" />
      </div>

      <TrendChartCard
        title="New Members Trend"
        grain={grain}
        onGrainChange={onGrainChange}
        isLoading={isLoading}
        isEmpty={!isLoading && !hasData}
        emptyMessage="No new members in this range"
        ariaLabel="New members and cumulative total for the selected range"
      >
        <DualLineTrend points={chartPoints} ariaLabel="Line chart of new members and cumulative total" />
      </TrendChartCard>

      <RecordsTable
        title="New Members"
        columns={columns}
        rows={records}
        rowKey={r => r.id}
        searchFields={r => [r.memberName, r.memberCode, r.planName, r.day]}
        searchPlaceholder="Search by member name, ID or date…"
        searchValue={search}
        onSearchChange={setSearch}
        isLoading={isLoading}
        emptyMessage="No new members match these filters"
      />
    </div>
  )
}
