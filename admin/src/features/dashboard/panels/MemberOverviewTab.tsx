import { useState } from 'react'
import { UserCheck, UserMinus, UserPlus, Users } from 'lucide-react'
import KpiCard from '@/components/KpiCard'
import RecordsTable, { type RecordsColumn } from '@/components/RecordsTable'
import Badge from '@/components/Badge'
import TabHeader, { PLAN_FILTER_OPTIONS, type TabPanelProps } from '@/features/dashboard/components/TabHeader'
import TrendChartCard from '@/features/dashboard/components/TrendChartCard'
import { StatusDonut } from '@/features/dashboard/components/TrendCharts'
import { fmtDay, formatRangeLabel } from '@/features/dashboard/lib/dateRange'
import type { PlanFilter } from '@/features/dashboard/lib/planFilter'
import { useMemberOverviewTab, type MemberOverviewRecord, type Slice } from '@/features/dashboard/hooks/useMemberOverviewTab'

function SlicePanel({ title, slices, emptyMessage }: { title: string; slices: Slice[]; emptyMessage: string }) {
  return (
    <div className="flex flex-col h-full min-h-0">
      <p className="text-[12px] font-semibold text-fg-muted mb-1">{title}</p>
      <div className="flex-1 min-h-0">
        <StatusDonut slices={slices} ariaLabel={`${title} breakdown`} emptyMessage={emptyMessage} />
      </div>
    </div>
  )
}

export default function MemberOverviewTab(props: TabPanelProps) {
  const { range, onRangeChange, plan, onPlanChange } = props
  const { total, active, inactive, newInRange, genderSlices, statusSlices, records, isLoading } =
    useMemberOverviewTab(range, plan)
  const [search, setSearch] = useState('')

  const columns: RecordsColumn<MemberOverviewRecord>[] = [
    { key: 'name', header: 'Member Name', render: r => <span className="font-medium text-fg-strong">{r.memberName}</span> },
    { key: 'code', header: 'Member ID', render: r => <span className="font-mono text-[12px] text-fg-muted">{r.memberCode ?? '—'}</span> },
    { key: 'plan', header: 'Membership Type', render: r => <Badge tone="purple">{r.planName}</Badge> },
    { key: 'gender', header: 'Gender', render: r => <span className="text-fg-muted">{r.genderLabel}</span> },
    {
      key: 'last',
      header: 'Last Check-in',
      render: r => (r.lastCheckIn ? <span className="text-fg-strong">{fmtDay(r.lastCheckIn)}</span> : <span className="text-fg-faint">Never</span>),
    },
    { key: 'status', header: 'Status', render: r => <Badge tone={r.status === 'Active' ? 'green' : 'red'}>{r.status}</Badge> },
  ]

  const hasData = total > 0

  return (
    <div className="flex flex-col gap-3.5">
      <TabHeader
        title="Member Overview"
        subtitle="Everyone on the books, who actually visited the selected window, and whose membership they are on."
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
        <KpiCard title="Total Members" value={total.toLocaleString()} sub={formatRangeLabel(range)} icon={Users} tone="purple" />
        <KpiCard title="Active Members" value={active.toLocaleString()} sub="visited in the selected range" icon={UserCheck} tone="green" />
        <KpiCard title="Inactive Members" value={inactive.toLocaleString()} sub="no visit in this range" icon={UserMinus} tone="amber" />
        <KpiCard title="New in Range" value={newInRange.toLocaleString()} sub="accounts created in range" icon={UserPlus} tone="blue" />
      </div>

      <TrendChartCard
        title="Member Distribution"
        isLoading={isLoading}
        isEmpty={!isLoading && !hasData}
        emptyMessage="No members match these filters"
        ariaLabel="Gender and activity breakdown of members"
      >
        <div className="h-full w-full grid grid-cols-1 md:grid-cols-2 gap-4">
          <SlicePanel title="Gender" slices={genderSlices} emptyMessage="No gender data" />
          <SlicePanel title="Activity Status" slices={statusSlices} emptyMessage="No members" />
        </div>
      </TrendChartCard>

      <RecordsTable
        title="Members"
        columns={columns}
        rows={records}
        rowKey={r => r.id}
        searchFields={r => [r.memberName, r.memberCode, r.planName, r.lastCheckIn]}
        searchPlaceholder="Search by member name, ID or plan…"
        searchValue={search}
        onSearchChange={setSearch}
        isLoading={isLoading}
        emptyMessage="No members match these filters"
      />
    </div>
  )
}
