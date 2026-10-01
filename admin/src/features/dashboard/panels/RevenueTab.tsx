import { useState } from 'react'
import { Banknote, CalendarRange, Receipt, TrendingUp } from 'lucide-react'
import KpiCard from '@/components/KpiCard'
import RecordsTable, { type RecordsColumn } from '@/components/RecordsTable'
import Badge from '@/components/Badge'
import TabHeader, { PLAN_FILTER_OPTIONS, type TabPanelProps } from '@/features/dashboard/components/TabHeader'
import TrendChartCard, { TREND_CHART_HEIGHT } from '@/features/dashboard/components/TrendChartCard'
import { BarTrend } from '@/features/dashboard/components/TrendCharts'
import { fmtDay, formatRangeLabel } from '@/features/dashboard/lib/dateRange'
import type { PlanFilter } from '@/features/dashboard/lib/planFilter'
import { useRevenueTab, type RevenueRecord } from '@/features/dashboard/hooks/useRevenueTab'

const peso = (n: number) => `₱${n.toLocaleString()}`

/**
 * A `price` of 0 is a real membership: a free trial, not a missing value.
 *
 * The table used to print those as a bare PHP 0, which sat under a Total Revenue
 * of over a million and read as a bug - the demo data has 11 free trials that all
 * started on the seed date, so the newest page of the table was entirely zero-amount
 * rows while the paid rows sat further down. Labelling them removes the contradiction
 * without hiding a real transaction.
 */

export default function RevenueTab(props: TabPanelProps) {
  const { range, onRangeChange, plan, onPlanChange, grain, onGrainChange, grainOptions } = props
  const { total, avg, days, transactions, peakDay, peakAmount, points, records, isLoading } =
    useRevenueTab(range, plan, grain)
  const [search, setSearch] = useState('')

  const columns: RecordsColumn<RevenueRecord>[] = [
    { key: 'date', header: 'Date', render: r => <span className="text-fg-strong">{fmtDay(r.startDate)}</span> },
    { key: 'name', header: 'Member Name', render: r => <span className="font-medium text-fg-strong">{r.memberName}</span> },
    { key: 'code', header: 'Member ID', render: r => <span className="font-mono text-[12px] text-fg-muted">{r.memberCode ?? '—'}</span> },
    { key: 'plan', header: 'Membership Type', render: r => <Badge tone="purple">{r.planName}</Badge> },
    // A zero-price membership is a free trial, not a failed transaction. Labelling it
    // keeps the row honest and stops a column of PHP 0 contradicting the total above.
    { key: 'amount', header: 'Amount', render: r => r.price > 0
      ? <span className="font-semibold text-fg-strong tabular-nums">{peso(r.price)}</span>
      : <Badge tone='muted'>Free Trial</Badge> },
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
        <KpiCard isLoading={isLoading} title="Total Revenue" value={peso(total)} sub={formatRangeLabel(range)} icon={Banknote} tone="green" />
        <KpiCard isLoading={isLoading} title="Daily Revenue" value={peso(Math.round(avg))} sub={`${days} day${days === 1 ? '' : 's'} in range`} icon={TrendingUp} tone="blue" />
        <KpiCard isLoading={isLoading} title="Total Transactions" value={transactions.toLocaleString()} sub="Memberships started in range" icon={Receipt} tone="purple" />
        <KpiCard isLoading={isLoading}
          title="Highest Revenue Day"
          value={peakDay ? peso(peakAmount) : peso(0)}
          sub={peakDay ? fmtDay(peakDay) : 'No sales in range'}
          icon={CalendarRange}
          tone="amber"
        />
      </div>

      <TrendChartCard
        heightClass={TREND_CHART_HEIGHT}
        title="Revenue Trend"
        grain={grain}
        grainOptions={grainOptions}
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
        pageSize={10}
      />
    </div>
  )
}
