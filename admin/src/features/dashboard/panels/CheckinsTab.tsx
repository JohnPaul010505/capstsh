import { useState } from 'react'
import { CalendarCheck, Crown, Users, UsersRound } from 'lucide-react'
import KpiCard from '@/components/KpiCard'
import RecordsTable, { type RecordsColumn } from '@/components/RecordsTable'
import Badge from '@/components/Badge'
import TabHeader, { PLAN_FILTER_OPTIONS, type TabPanelProps } from '@/features/dashboard/components/TabHeader'
import TrendChartCard from '@/features/dashboard/components/TrendChartCard'
import { BarTrend } from '@/features/dashboard/components/TrendCharts'
import { fmtDay, formatRangeLabel } from '@/features/dashboard/lib/dateRange'
import type { PlanFilter } from '@/features/dashboard/lib/planFilter'
import { useCheckinsTab, type CheckinRecord } from '@/features/dashboard/hooks/useCheckinsTab'

const entryBadge = (method: string | null) => {
  if (method === 'manual') return <Badge tone="amber">Manual</Badge>
  if (method === 'qr') return <Badge tone="green">QR Code</Badge>
  return <span className="text-fg-faint">—</span>
}

export default function CheckinsTab(props: TabPanelProps) {
  const { range, onRangeChange, plan, onPlanChange, grain, onGrainChange } = props
  const { total, memberCount, trainerCount, avg, days, points, records, isLoading } =
    useCheckinsTab(range, plan, grain)
  const [search, setSearch] = useState('')

  const columns: RecordsColumn<CheckinRecord>[] = [
    {
      key: 'when',
      header: 'Date & Time',
      render: r => (
        <div className="leading-tight">
          <span className="text-fg-strong">{fmtDay(r.check_in_date)}</span>
          <span className="ml-2 text-fg-muted text-[12px]">{timeOf(r.check_in_time)}</span>
        </div>
      ),
    },
    { key: 'name', header: 'Member Name', render: r => <span className="font-medium text-fg-strong">{r.profiles?.full_name ?? 'Unknown'}</span> },
    { key: 'code', header: 'Member ID', render: r => <span className="font-mono text-[12px] text-fg-muted">{r.profiles?.code ?? r.member_id.slice(0, 8)}</span> },
    { key: 'plan', header: 'Membership Type', render: r => <Badge tone="purple">{r.planName ?? '—'}</Badge> },
    { key: 'entry', header: 'Entry Method', render: r => entryBadge(r.entry_method) },
  ]

  const chartPoints = points.map(p => ({ key: p.key, label: p.label, full: p.full, value: p.count }))
  const hasData = chartPoints.some(p => p.value > 0)

  return (
    <div className="h-full min-h-0 flex flex-col gap-3.5">
      <TabHeader
        title="Daily Check-ins"
        subtitle="Every visit recorded in the selected window, split by member and trainer, with how the member got in."
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
        <KpiCard title="Total Check-ins" value={total.toLocaleString()} sub={formatRangeLabel(range)} icon={CalendarCheck} tone="purple" />
        <KpiCard title="Members" value={memberCount.toLocaleString()} sub={`${(memberCount / days).toFixed(1)} member visits / day`} icon={Users} tone="blue" />
        <KpiCard title="Trainers" value={trainerCount.toLocaleString()} sub={`${(trainerCount / days).toFixed(1)} trainer visits / day`} icon={Crown} tone="amber" />
        <KpiCard title="Average per Day" value={avg.toFixed(1)} sub={`${days} day${days === 1 ? '' : 's'} in range`} icon={UsersRound} tone="green" />
      </div>

      <TrendChartCard
        title="Check-ins Trend"
        grain={grain}
        onGrainChange={onGrainChange}
        isLoading={isLoading}
        isEmpty={!isLoading && !hasData}
        emptyMessage="No check-ins in this range"
        ariaLabel="Check-ins per period for the selected range"
      >
        <BarTrend points={chartPoints} ariaLabel="Bar chart of check-ins per period" valueName="Check-ins" gradientId="checkinsGrad" />
      </TrendChartCard>

      <RecordsTable
        title="Records"
        columns={columns}
        rows={records}
        rowKey={r => r.id}
        searchFields={r => [r.profiles?.full_name, r.profiles?.code, r.planName, r.check_in_date]}
        searchPlaceholder="Search by member name, ID or date…"
        searchValue={search}
        onSearchChange={setSearch}
        isLoading={isLoading}
        emptyMessage="No check-ins match these filters"
      />
    </div>
  )
}

function timeOf(iso: string) {
  if (!iso) return ''
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return ''
  return d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })
}
