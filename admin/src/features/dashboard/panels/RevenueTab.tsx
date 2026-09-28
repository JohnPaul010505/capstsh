import { useState } from 'react'
import { Banknote, CalendarRange, Receipt, TrendingUp } from 'lucide-react'
import KpiCard from '@/components/KpiCard'
import RecordsTable, { type RecordsColumn } from '@/components/RecordsTable'
import Badge from '@/components/Badge'
import TabHeader, { PLAN_FILTER_OPTIONS, type TabPanelProps } from '@/features/dashboard/components/TabHeader'
import TrendChartCard from '@/features/dashboard/components/TrendChartCard'
import { BarTrend } from '@/features/dashboard/components/TrendCharts'
import { fmtDay, formatRangeLabel } from '@/features/dashboard/lib/dateRange'
import type { PlanFilter } from '@/features/dashboard/lib/planFilter'
import { useRevenueTab, type RevenueRecord } from '@/features/dashboard/hooks/useRevenueTab'

const peso = (n: number) => `₱${n.toLocaleString()}`

export default function RevenueTab(props: TabPanelProps) {
  const { range, onRangeChange, plan, onPlanChange, grain, onGrainChange } = props
  const { total, avg, days, transactions, peakDay, peakAmount, points, records, isLoading } =
    useRevenueTab(range, plan, grain)
  const [search, setSearch] = useState('')

  const columns: RecordsColumn<RevenueRecord>[] = [
    { key: 'date', header: 'Date', render: r => <span className="text-fg-strong">{fmtDay(r.startDate)}</span> },
    { key: 'name', header: 'Member Name', render: r => <span className="font-medium text-fg-strong">{r.memberName}</span> },
    { key: 'code', header: 'Member ID', render: r => <span className="font-mono text-[12px] text-fg-muted">{r.memberCode ?? '—'}</span> },
    { key: 'plan', header: 'Membership Type', render: r => <Badge tone="purple">{r.planName}</Badge> },
    { key: 'amount', header: 'Amount', render: r => <span className="font-semibold text-fg-strong tabular-nums">{peso(r.price)}</span> },
    {
      key: 'status',
      header: 'Status',
      render: r => <Badge tone={r.status === 'active' ? 'green' : r.status === 'expired' ? 'red' : 'muted'}>{r.status}</Badge>,
    },
  ]

  const chartPoints = points.map(p => ({ key: p.key, label: p.label, full: p.full, value: p.value }))
  const hasData = chartPoints.some(p => p.value > 0)

  return (
    <div className="h-full min-h-0 flex flex-col gap-3.5">
      <TabHeader
        title="Revenue Overview"
        subtitle="Membership sales recorded inside the selected window, using each plan's start day as the transaction date."
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
        <KpiCard title="Total Revenue" value={peso(total)} sub={formatRangeLabel(range)} icon={Banknote} tone="green" />
        <KpiCard title="Daily Revenue" value={peso(Math.round(avg))} sub={`${days} day${days === 1 ? '' : 's'} in range`} icon={TrendingUp} tone="blue" />
        <KpiCard title="Total Transactions" value={transactions.toLocaleString()} sub="Memberships started in range" icon={Receipt} tone="purple" />
        <KpiCard
          title="Highest Revenue Day"
          value={peakDay ? peso(peakAmount) : peso(0)}
          sub={peakDay ? fmtDay(peakDay) : 'No sales in range'}
          icon={CalendarRange}
          tone="amber"
        />
      </div>

      <TrendChartCard
        title="Revenue Trend"
        grain={grain}
        onGrainChange={onGrainChange}
        isLoading={isLoading}
        isEmpty={!isLoading && !hasData}
        emptyMessage="No revenue in this range"
        ariaLabel="Revenue per period for the selected range"
      >
        <BarTrend points={chartPoints} ariaLabel="Bar chart of revenue per period" valueName="Revenue" gradientId="revenueGrad" />
      </TrendChartCard>

      <RecordsTable
        title="Transactions"
        columns={columns}
        rows={records}
        rowKey={r => r.id}
        searchFields={r => [r.memberName, r.memberCode, r.planName, r.startDate]}
        searchPlaceholder="Search by member, plan or date…"
        searchValue={search}
        onSearchChange={setSearch}
        isLoading={isLoading}
        emptyMessage="No transactions match these filters"
      />
    </div>
  )
}
