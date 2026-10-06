import { useState } from 'react'
import { Activity as ActivityIcon, CalendarDays, Crown, UserPlus } from 'lucide-react'
import KpiCard from '@/components/KpiCard'
import RecordsTable, { type RecordsColumn } from '@/components/RecordsTable'
import Badge from '@/components/Badge'
import TabHeader, { PLAN_FILTER_OPTIONS, type TabPanelProps } from '@/features/dashboard/components/TabHeader'
import TrendChartCard, { TREND_CHART_HEIGHT } from '@/features/dashboard/components/TrendChartCard'
import { GrowthAreaTrend } from '@/features/dashboard/components/TrendCharts'
import { fmtDay, formatRangeLabel } from '@/features/dashboard/lib/dateRange'
import type { PlanFilter } from '@/features/dashboard/lib/planFilter'
import { useGrowthTab, type GrowthRecord } from '@/features/dashboard/hooks/useGrowthTab'

export default function GrowthTab(props: TabPanelProps) {
  const { range, onRangeChange, plan, onPlanChange, grain, onGrainChange, grainOptions } = props
  const { totalNew, avg, days, peakDay, peakCount, activeCount, points, records, isLoading } =
    useGrowthTab(range, plan, grain)
  const [search, setSearch] = useState('')

  const columns: RecordsColumn<GrowthRecord>[] = [
    /* Date and time are two columns rather than one "Date & Time" cell: two
       lines in one cell would make the row ~60px against `RecordsTable`'s flat
       44px budget, which clips the bottom of the pinned 10-row table instead
       of scrolling it. `whitespace-nowrap` is what keeps each column on one
       line - without it a narrow date column wraps and the row grows anyway. */
    {
      key: 'date',
      header: 'Date',
      render: r => <span className="text-fg-strong whitespace-nowrap">{fmtDay(r.day)}</span>,
    },
    {
      key: 'time',
      header: 'Time',
      render: r => <span className="text-fg-muted text-[12px] whitespace-nowrap">{new Date(r.createdAt).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}</span>,
    },
    { key: 'name', header: 'Member Name', render: r => <span className="font-medium text-fg-strong">{r.memberName}</span> },
    { key: 'code', header: 'Member ID', render: r => <span className="font-mono text-[12px] text-fg-muted">{r.memberCode ?? '—'}</span> },
    { key: 'plan', header: 'Membership Type', render: r => <Badge tone="purple">{r.planName}</Badge> },
    { key: 'status', header: 'Status', render: r => <Badge tone={r.status === 'Active' ? 'green' : 'muted'}>{r.status}</Badge> },
  ]

  const chartPoints = points.map(p => ({ key: p.key, label: p.label, full: p.full, value: p.value }))
  const hasData = chartPoints.some(p => p.value > 0)

  return (
    <div className="h-full min-h-0 flex flex-col gap-3.5">
      <TabHeader
        title="Member Growth"
        subtitle="New members who joined inside the selected window."
        range={range}
        onRangeChange={onRangeChange}
        filter={{
          options: PLAN_FILTER_OPTIONS,
          value: plan === 'all' ? '' : plan,
          onChange: v => onPlanChange((v || 'all') as PlanFilter),
          placeholder: 'All Membership Types',
        }}
      />

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <KpiCard isLoading={isLoading} title="Total New Members" value={totalNew.toLocaleString()} sub={formatRangeLabel(range)} icon={UserPlus} tone="purple" />
        <KpiCard isLoading={isLoading} title="Daily Average" value={avg.toFixed(1)} sub={`${days} day${days === 1 ? '' : 's'} in range`} icon={ActivityIcon} tone="blue" />
        <KpiCard isLoading={isLoading}
          title="Highest Growth Day"
          value={peakCount > 0 ? peakCount.toLocaleString() : '0'}
          sub={peakDay ? `${fmtDay(peakDay)} · new members` : 'No growth in range'}
          icon={CalendarDays}
          tone="amber"
        />
        <KpiCard isLoading={isLoading} title="Active in Range" value={activeCount.toLocaleString()} sub="members with at least one visit" icon={Crown} tone="green" />
      </div>

      <TrendChartCard
        heightClass={TREND_CHART_HEIGHT}
        title="New Members Trend"
        grain={grain}
        grainOptions={grainOptions}
        onGrainChange={onGrainChange}
        isLoading={isLoading}
        isEmpty={!isLoading && !hasData}
        emptyMessage="No new members in this range"
        ariaLabel="New members per period for the selected range"
      >
        <GrowthAreaTrend
          points={chartPoints}
          ariaLabel="Area chart of new members per period for the selected range"
        />
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
        pageSize={10}
      />
    </div>
  )
}
