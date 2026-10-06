import DateRangePicker from '@/components/DateRangePicker'
import { LIST_PRESETS, type Range, type RangePreset } from '@/features/dashboard/lib/dateRange'

/**
 * The strip of page-level controls that sits ABOVE the list card, shared by the
 * members, trainers, memberships, attendance, coach-feedback, predictions and
 * notifications pages so all of them read identically.
 *
 * One row, three slots. `left` is pinned to the start: the memberships tab
 * strip uses it, and so does Coach Feedback, which puts its rating KPI card
 * there so the card and the date filter share one line instead of the card
 * sitting alone and centred above the filter. Everything else - the date-range
 * filter and the page's action button - collects in a right-aligned cluster,
 * which is where an admin's eye already goes for controls on every one of these
 * pages.
 *
 * It used to own a "Joined" / "Hired" toggle button that revealed two raw date
 * inputs inline. That is gone: it was a second, plainer spelling of the
 * dashboard's own picker, it had no presets, and it left the popover's
 * `absolute right-0` anchoring to fight an input that sat in normal flow. Every
 * page now uses `DateRangePicker`, so the start/end inputs, the preset chips
 * and the "Apply range" button are literally the same code the dashboard's
 * charts are filtered by.
 *
 * The search box is not here either - it lives in each table's own card header,
 * beside the title, which is where the QR queue and every dashboard tab have
 * always kept theirs.
 */
export interface ListToolbarProps {
  /** Control pinned left (e.g. the memberships tab strip). */
  left?: React.ReactNode
  /** The selected window. Omit together with `onRangeChange` for no date control. */
  range?: Range
  onRangeChange?: (range: Range) => void
  /**
   * Preset chips inside the picker's popover. Defaults to `LIST_PRESETS`
   * (Today / Last 7 days / This month / All time), which is right for a table
   * of rows; attendance passes `MONTH_PRESETS` because a gym reads check-ins a
   * month at a time.
   */
  presets?: RangePreset[]
  /** The page's action button(s), rendered after the date control. */
  children?: React.ReactNode
}

export default function ListToolbar({
  left, range, onRangeChange, presets = LIST_PRESETS, children,
}: ListToolbarProps) {
  return (
    <div className="flex flex-wrap items-center gap-2 shrink-0">
      {left}
      <div className="flex items-center gap-2 ml-auto">
        {range && onRangeChange && (
          <DateRangePicker value={range} onChange={onRangeChange} presets={presets} />
        )}
        {children}
      </div>
    </div>
  )
}
