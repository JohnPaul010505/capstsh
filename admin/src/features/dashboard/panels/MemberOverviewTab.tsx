import { useState } from 'react'
import { UserCheck, UserMinus, UserPlus, Users } from 'lucide-react'
import KpiCard from '@/components/KpiCard'
import RecordsTable, { type RecordsColumn } from '@/components/RecordsTable'
import Badge from '@/components/Badge'
import TabHeader, { PLAN_FILTER_OPTIONS, type TabPanelProps } from '@/features/dashboard/components/TabHeader'
import TrendChartCard from '@/features/dashboard/components/TrendChartCard'
import { MemberDistributionDonut, SLICE_COLORS } from '@/features/dashboard/components/TrendCharts'
import { useMediaQuery } from '@/hooks/useMediaQuery'
import { fmtDay, formatRangeLabel } from '@/features/dashboard/lib/dateRange'
import type { PlanFilter } from '@/features/dashboard/lib/planFilter'
import { useMemberOverviewTab, type MemberOverviewRecord, type Slice } from '@/features/dashboard/hooks/useMemberOverviewTab'

/**
 * This card's own height ladder, which matches the shared `TREND_CHART_HEIGHT`
 * at every viewport EXCEPT the two shortest bands.
 *
 * The shared ladder bottoms out at 84px and 104px below 760px of viewport
 * height. That was fine when the two breakdown groups sat side by side and the
 * box needed ~66px; stacked, they need ~116px, and at 84px the Activity Status
 * group was painted over the card's bottom edge and into the Members table
 * below it. Nothing would have said so - the tabpanel is `overflow-hidden`, so a
 * too-tall card reports no scrollbar, it just hides its own content.
 *
 * So the two short floors are raised to 128px - what 768px-tall windows already
 * got - and the 850px/950px steps are left exactly as they were. The cost is
 * measured, not asserted: at 1152x700 this panel has 134px of room for the
 * card, and the `Members` `RecordsTable` below is `flex-1` and derives its page
 * size by MEASURING what it is given (`useFitRows`), so a taller card here just
 * means a page one row shorter.
 */
const DISTRIBUTION_HEIGHT =
  'h-[128px] [@media(min-height:850px)]:h-[160px] [@media(min-height:950px)]:h-[200px]'

/**
 * The right-hand half of the distribution card: both dimensions written out as
 * counts, each closed by a proportional bar.
 *
 * These rows used to sit directly beside the donut's own legend, which made the
 * card state the same five numbers twice within 150px of each other. The legend
 * is gone, and this is now the only place the breakdown is written out.
 *
 * The groups are STACKED, Gender above Activity Status, in the order a reader
 * takes them: the outer ring is gender, the nested ring is activity, so the
 * list runs top-to-bottom in the same sequence the eye travels the circles.
 * They used to sit side by side, which halved the height but read as two
 * columns of unrelated facts - and it was only affordable because the box was
 * the shared `TREND_CHART_HEIGHT`, which bottoms out at 128px on a 768px-tall
 * window. A stacked pair needs ~130px, so this card now carries its own, taller
 * box (see DISTRIBUTION_HEIGHT) rather than silently clipping the second group.
 *
 * The closing sentence ("22% of members checked in during this window...") is
 * gone - the donut's centre carries that rate and the groups beside it carry
 * the counts, so the sentence was a third telling of the same two numbers in
 * the most expensive format available.
 *
 * Both groups are kept even though BOTH are now on the circles as well: the
 * arcs carry no labels of their own, so these rows are the only place the
 * numbers are readable without hovering and without decoding an arc.
 */
function BreakdownStats({ genderSlices, statusSlices, unrecordedGender }: {
  genderSlices: Slice[]
  statusSlices: Slice[]
  /** Members with no gender on file: reported as a note, never charted. */
  unrecordedGender: number
}) {
  const Group = ({ label, slices, aside }: { label: string; slices: Slice[]; aside?: string }) => {
    const sum = slices.reduce((s, x) => s + x.value, 0)
    return (
      <div className="flex flex-col gap-0.5 min-w-0">
        {/* The unrecorded count rides the label row instead of taking a line of
            its own: it is context for the group, not a category in it, and a
            dedicated row is height this box cannot spare.

            The explicit `leading-*` on all three rows is what makes the STACKED
            pair fit. Tailwind's arbitrary `text-[11px]` / `text-[12px]` set only
            the font size, so the line box came from the inherited 1.5 - about
            16.5px and 18px respectively, and two groups stacked came to ~143px
            against a 128px box. Pinning 12px / 16px line boxes brings the pair
            to ~116px, which fits the shared ladder's floor with room to spare,
            so this card does not need a taller box than the other four tabs
            and the dashboard keeps its exact height budget. */}
        <div className="flex items-baseline justify-between gap-2">
          <p className="text-[11px] leading-3 uppercase tracking-wide text-fg-faint truncate">{label}</p>
          {aside && <p className="text-[10px] leading-3 text-fg-faint shrink-0 tabular-nums">{aside}</p>}
        </div>
        {slices.map(s => (
          <div key={s.name} className="flex items-center gap-2 min-w-0 leading-4">
            <span className="w-2 h-2 rounded-full shrink-0" style={{ backgroundColor: SLICE_COLORS[s.name] ?? '#7C3AED' }} />
            <span className="text-[12px] text-fg-muted flex-1 truncate">{s.name}</span>
            <span className="text-[12px] font-semibold text-fg-strong tabular-nums">{s.value.toLocaleString()}</span>
            <span className="text-[11px] text-fg-faint w-8 text-right tabular-nums">
              {sum > 0 ? Math.round((s.value / sum) * 100) : 0}%
            </span>
          </div>
        ))}
        {/* The bar carries the proportion for a group that is no longer an arc,
            so it is what makes "half and half" readable at a glance. */}
        <div className="h-1.5 rounded-full overflow-hidden flex gap-0.5">
          {slices.map(s => (
            <span
              key={s.name}
              className="h-full rounded-full"
              style={{ width: sum > 0 ? `${(s.value / sum) * 100}%` : '0%', backgroundColor: SLICE_COLORS[s.name] ?? '#7C3AED' }}
            />
          ))}
        </div>
      </div>
    )
  }

  return (
    /* `justify-center` rather than `justify-between`: the two groups are about
       130px and the box is 168-220px, and spreading them pins the top one to
       the title and floats the bottom one in the middle, which reads as two
       cards instead of one list. */
    <div className="h-full min-w-0 flex flex-col justify-center gap-2.5">
      <Group
        label="Gender"
        slices={genderSlices}
        aside={unrecordedGender > 0 ? `${unrecordedGender} not recorded` : undefined}
      />
      <Group label="Activity Status" slices={statusSlices} />
    </div>
  )
}
export default function MemberOverviewTab(props: TabPanelProps) {
  const { range, onRangeChange, plan, onPlanChange } = props
  const { total, active, inactive, newInRange, genderSlices, unrecordedGender, statusSlices, records, isLoading } =
    useMemberOverviewTab(range, plan)
  const [search, setSearch] = useState('')
  // Same 1024px that Tailwind's `lg` means. See `useMediaQuery`: the donut is
  // skipped entirely below it, not hidden, so Recharts never mounts it at 0x0.
  const showDonut = useMediaQuery('(min-width: 1024px)')

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
    <div className="h-full min-h-0 flex flex-col gap-3.5">
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

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <KpiCard isLoading={isLoading} title="Total Members" value={total.toLocaleString()} sub={formatRangeLabel(range)} icon={Users} tone="purple" />
        <KpiCard isLoading={isLoading} title="Active Members" value={active.toLocaleString()} sub="visited in the selected range" icon={UserCheck} tone="green" />
        <KpiCard isLoading={isLoading} title="Inactive Members" value={inactive.toLocaleString()} sub="no visit in this range" icon={UserMinus} tone="amber" />
        <KpiCard isLoading={isLoading} title="New in Range" value={newInRange.toLocaleString()} sub="accounts created in range" icon={UserPlus} tone="blue" />
      </div>

      {/*
        HALF WIDTH AND CENTRED.

        The card used to stretch the whole 1,690px panel and put its ring hard
        left with both groups pushed to the far right, so the two ends of the
        card described the same roster from a long way apart and the middle was
        empty. It is now a centred column of half the panel.

        The classes are not `w-1/2` alone. The panel is 1,690px at 1920 but only
        1,136px at 1366 and 796px at 1024, and half of 796 (398px) cannot hold a
        128px ring plus two groups - the tabpanel is `overflow-hidden`, so the
        result would be a card that looks right and silently cuts its own
        content. So: `lg` (the same 1024 the donut is gated on) to halve,
        `min-w-[44rem]` to stop it going below what the contents can use, and
        `max-w-[52rem]` to stop 2560-wide monitors from getting a 1,280px
        "half" card - which is the whole complaint again. Below `lg` it stays
        full width, which is where the donut is not mounted anyway.

        The Members table below deliberately stays full width: the request was
        about this one card being too long, not about the tab.
      */}
      <div className="mx-auto w-full lg:w-1/2 lg:min-w-[44rem] lg:max-w-[52rem] shrink-0">
        <TrendChartCard
          heightClass={DISTRIBUTION_HEIGHT}
          title="Member Distribution"
          isLoading={isLoading}
          isEmpty={!isLoading && !hasData}
          emptyMessage="No members match these filters"
          ariaLabel="Nested rings: member gender outside, activity status inside"
        >
          {/* One row. The donut's column is `aspect-square` off a full-height flex
              line, so the ring is exactly as wide as it is tall and scales with the
              card. It used to be a `flex-1` column 661px wide holding a ring only
              200px across, so the ring floated in the middle with more empty space
              either side of it than space around it.

              Below `lg` the donut is not rendered at all rather than hidden with a
              class. Under that width the card is full-panel width but still
              bounded in height, and a 2-ring chart plus a stacked two-group
              breakdown does not fit in it - which is precisely how this card
              came to paint over its own bottom edge. `useMediaQuery` is what
              makes "not rendered" possible: a chart inside a `hidden` wrapper
              still mounts at 0x0 and makes Recharts log a width/height warning
              on every resize. The two groups carry every number on their own
              down there, so what is lost is the decoration, not the data. */}
          <div className="h-full w-full flex items-center gap-5 lg:gap-6 min-w-0">
            {showDonut && (
              <div className="h-full aspect-square shrink-0">
                <MemberDistributionDonut
                  genderSlices={genderSlices}
                  statusSlices={statusSlices}
                  total={total}
                  active={active}
                  ariaLabel="Nested rings of member gender and activity status"
                  emptyMessage="No members match these filters"
                />
              </div>
            )}
            <div className="flex-1 min-w-0 h-full">
              <BreakdownStats
                genderSlices={genderSlices}
                statusSlices={statusSlices}
                unrecordedGender={unrecordedGender}
              />
            </div>
          </div>
        </TrendChartCard>
      </div>

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
        pageSize={10}
      />
    </div>
  )
}
