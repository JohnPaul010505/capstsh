import { useState } from 'react'
import { CheckCircle2, LogIn, LogOut, UserRound } from 'lucide-react'
import KpiCard from '@/components/KpiCard'
import RecordsTable, { type RecordsColumn } from '@/components/RecordsTable'
import Badge, { type BadgeTone } from '@/components/Badge'
import TabHeader, { type TabPanelProps } from '@/features/dashboard/components/TabHeader'
import TrendChartCard, { TREND_CHART_HEIGHT } from '@/features/dashboard/components/TrendChartCard'
import { BarTrend } from '@/features/dashboard/components/TrendCharts'
import { fmtDay, formatRangeLabel } from '@/features/dashboard/lib/dateRange'
import { ACTIVITY_TYPE_OPTIONS, type ActivityType } from '@/features/dashboard/lib/activityFeed'
import { useActivityTab, type ActivityPoint } from '@/features/dashboard/hooks/useActivityTab'

export interface ActivityTabProps extends TabPanelProps {
  activityType: ActivityType | 'all'
  onActivityTypeChange: (t: ActivityType | 'all') => void
}

const TYPE_META: Record<ActivityType, { label: string; tone: BadgeTone }> = {
  checkin: { label: 'Check-in', tone: 'green' },
  checkout: { label: 'Check-out', tone: 'amber' },
  membership: { label: 'Membership', tone: 'purple' },
  enrollment: { label: 'Enrollment', tone: 'blue' },
  trainer: { label: 'Trainer', tone: 'blue' },
  expiring: { label: 'Expiring', tone: 'red' },
  feedback: { label: 'Feedback', tone: 'muted' },
  inactive: { label: 'Inactive', tone: 'red' },
}

const timeOf = (iso: string) => {
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return ''
  return d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })
}

export default function ActivityTab({ activityType, onActivityTypeChange, ...props }: ActivityTabProps) {
  const { range, onRangeChange, plan, grain, onGrainChange, grainOptions } = props
  const { total, checkins, checkouts, people, days, points, records, isLoading } =
    useActivityTab(range, plan, activityType, grain)
  const [search, setSearch] = useState('')

  const columns: RecordsColumn<(typeof records)[number]>[] = [
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
      render: r => <span className="text-fg-muted text-[12px] whitespace-nowrap">{timeOf(r.ts)}</span>,
    },
    { key: 'name', header: 'Member Name', render: r => <span className="font-medium text-fg-strong">{r.memberName}</span> },
    { key: 'code', header: 'Member ID', render: r => <span className="font-mono text-[12px] text-fg-muted">{r.memberCode ?? '—'}</span> },
    {
      key: 'type',
      header: 'Activity Type',
      render: r => <Badge tone={TYPE_META[r.type].tone}>{TYPE_META[r.type].label}</Badge>,
    },
    { key: 'msg', header: 'Details', render: r => <span className="text-fg-muted">{r.message}</span> },
  ]

  const chartPoints: ActivityPoint[] = points.map(p => ({ key: p.key, label: p.label, full: p.full, value: p.value }))
  const hasData = chartPoints.some(p => p.value > 0)

  return (
    <div className="h-full min-h-0 flex flex-col gap-3.5">
      <TabHeader
        title="Recent Activity"
        subtitle="Everything that happened in the window — visits, sales, assignments, expiries and feedback — newest first."
        range={range}
        onRangeChange={onRangeChange}
        filter={{
          options: ACTIVITY_TYPE_OPTIONS.map(o => ({ id: o.id, label: o.label })),
          value: activityType,
          onChange: v => onActivityTypeChange((v || 'all') as ActivityType | 'all'),
          placeholder: 'All Activity Types',
        }}
      />

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <KpiCard isLoading={isLoading} title="Total Activities" value={total.toLocaleString()} sub={formatRangeLabel(range)} icon={CheckCircle2} tone="purple" />
        <KpiCard isLoading={isLoading} title="Check-ins" value={checkins.toLocaleString()} sub={`${(checkins / days).toFixed(1)} per day`} icon={LogIn} tone="green" />
        <KpiCard isLoading={isLoading} title="Check-outs" value={checkouts.toLocaleString()} sub={`${(checkouts / days).toFixed(1)} per day`} icon={LogOut} tone="amber" />
        <KpiCard isLoading={isLoading} title="Unique Members" value={people.toLocaleString()} sub="people appearing in this feed" icon={UserRound} tone="blue" />
      </div>

      <TrendChartCard
        heightClass={TREND_CHART_HEIGHT}
        title="Activity Trend"
        grain={grain}
        grainOptions={grainOptions}
        onGrainChange={onGrainChange}
        isLoading={isLoading}
        isEmpty={!isLoading && !hasData}
        emptyMessage="No activity in this range"
        ariaLabel="Activity count per period for the selected range"
      >
        <BarTrend points={chartPoints} ariaLabel="Bar chart of activity per period" valueName="Activities" gradientId="activityGrad" />
      </TrendChartCard>

      <RecordsTable
        title="Activity Feed"
        columns={columns}
        rows={records}
        rowKey={r => r.id}
        searchFields={r => [r.memberName, r.memberCode, r.message, r.day, TYPE_META[r.type].label]}
        searchPlaceholder="Search by member, type or date…"
        searchValue={search}
        onSearchChange={setSearch}
        isLoading={isLoading}
        emptyMessage="No activity matches these filters"
        pageSize={10}
      />
    </div>
  )
}
