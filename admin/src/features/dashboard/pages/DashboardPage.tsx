// Dashboard shell: tab bar + one panel at a time.
//
// The all-time summary row (Total Revenue / Members / Trainers / Attendance)
// was removed here. Every number it showed is already presented inside the
// panel that owns it — the Revenue tab has its own Total Revenue, the
// Check-ins tab its own total — so the row was a second, non-filterable copy of
// the same facts sitting above the filter that actually changes them. It also
// cost ~120px of vertical space, which is the difference between fitting the
// viewport and scrolling.
//
// Three hooks died with it: useDashboardBaseStats, useRevenueMonthlySummary
// and useGrowthData existed only to feed the cards' sparklines and were not
// used by any panel. StatsCard.tsx itself is NOT deleted - MemberDetailPage
// and TrainerDetailPage still use it.
import { useState } from 'react'
import { ClipboardList, LineChart as TrendIcon, UserPlus, Users, Wallet } from 'lucide-react'
import DashboardTabs, { type TabDef } from '@/features/dashboard/components/DashboardTabs'
import CheckinsTab from '@/features/dashboard/panels/CheckinsTab'
import RevenueTab from '@/features/dashboard/panels/RevenueTab'
import GrowthTab from '@/features/dashboard/panels/GrowthTab'
import MemberOverviewTab from '@/features/dashboard/panels/MemberOverviewTab'
import ActivityTab from '@/features/dashboard/panels/ActivityTab'
import { autoGrain, lastNDays, type Grain, type Range } from '@/features/dashboard/lib/dateRange'
import type { PlanFilter } from '@/features/dashboard/lib/planFilter'
import type { ActivityType } from '@/features/dashboard/lib/activityFeed'

const TABS: TabDef[] = [
  { id: 'checkins', label: 'Daily Check-ins', icon: ClipboardList },
  { id: 'revenue', label: 'Revenue Overview', icon: Wallet },
  { id: 'growth', label: 'Member Growth', icon: UserPlus },
  { id: 'members', label: 'Member Overview', icon: Users },
  { id: 'activity', label: 'Recent Activity', icon: TrendIcon },
]

export default function DashboardPage() {
  const [tab, setTab] = useState('checkins')
  const [range, setRange] = useState<Range>(() => lastNDays(30))
  const [grainOverride, setGrainOverride] = useState<Grain | null>(null)
  const [plan, setPlan] = useState<PlanFilter>('all')
  // 'all' is the panel's own "no filter" option, so it belongs in the state
  // type here rather than being forced through ActivityType.
  const [activityType, setActivityType] = useState<ActivityType | 'all'>('all')

  // Default the grain to whatever the chosen range implies, until the user
  // picks one explicitly.
  const grain = grainOverride ?? autoGrain(range)
  const panelProps = { range, onRangeChange: setRange, plan, onPlanChange: setPlan, grain, onGrainChange: setGrainOverride }

  return (
    <div className="h-full min-h-0 flex flex-col gap-3">
      <DashboardTabs tabs={TABS} value={tab} onChange={setTab} />

      {/* Viewport-fitted panel. `min-h-0` is load-bearing: without it a flex
          child refuses to shrink below its content, the panel grows past the
          viewport and the page scrolls — which is the whole thing this layout
          exists to prevent. The panels inside own their own scrolling. */}
      <div
        role="tabpanel"
        id={`dash-panel-${tab}`}
        aria-labelledby={`dash-tab-${tab}`}
        tabIndex={0}
        className="flex-1 min-h-0 overflow-hidden focus:outline-none"
      >
        <div className="h-full min-h-0">
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
