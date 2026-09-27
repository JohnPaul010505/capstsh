import DateRangePicker from '@/components/DateRangePicker'
import { MemberSelect, type SelectOption } from '@/components/MemberSelect'
import { type Grain, type Range } from '@/features/dashboard/lib/dateRange'
import type { PlanFilter } from '@/features/dashboard/lib/planFilter'

/**
 * Filter state lives in DashboardPage so it survives tab switches; every tab
 * receives the same shape and refetches through query keys that contain it.
 */
export interface TabPanelProps {
  range: Range
  onRangeChange: (r: Range) => void
  plan: PlanFilter
  onPlanChange: (p: PlanFilter) => void
  grain: Grain
  onGrainChange: (g: Grain) => void
}

export const PLAN_FILTER_OPTIONS: SelectOption[] = [
  { id: 'Daily', label: 'Daily' },
  { id: 'Monthly', label: 'Monthly' },
]

interface TabHeaderProps {
  title: string
  subtitle: string
  range: Range
  onRangeChange: (r: Range) => void
  /** Omitted on tabs that have no second filter (e.g. Member Overview). */
  filter?: {
    options: SelectOption[]
    value: string
    onChange: (v: string) => void
    placeholder: string
  }
}

/**
 * Sub-page header from the mockups: title + one-line purpose on the left,
 * the date range and type filters pinned right. Lives inside every tab panel
 * so switching tabs keeps the selected range while the filters stay put.
 */
export default function TabHeader({ title, subtitle, range, onRangeChange, filter }: TabHeaderProps) {
  return (
    <div className="flex flex-wrap items-start justify-between gap-3">
      <div className="min-w-0">
        <h1 className="text-lg font-bold text-fg-strong leading-tight">{title}</h1>
        <p className="mt-0.5 text-[12px] text-fg-muted max-w-2xl">{subtitle}</p>
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <DateRangePicker value={range} onChange={onRangeChange} />
        {filter && (
          <MemberSelect
            options={filter.options}
            value={filter.value}
            onChange={filter.onChange}
            placeholder={filter.placeholder}
            className="w-52"
            buttonClassName="px-3 py-2.5 rounded-xl bg-overlay-8 border-line"
          />
        )}
      </div>
    </div>
  )
}
