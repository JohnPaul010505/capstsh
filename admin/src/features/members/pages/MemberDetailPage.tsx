import { useMemo, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { useMember, useUpdateMember } from '../hooks/useMembers'
import { usePagedTable, useResetPageOnChange } from '@/lib/pagedTable'
import { useFitRowHeight } from '@/hooks/useFitRows'
import PeopleTable, { type PeopleColumn } from '@/components/PeopleTable'
import PaginationFooter from '@/components/PaginationFooter'
import DateRangePicker from '@/components/DateRangePicker'
import { BarTrend, GrowthAreaTrend, type TrendPoint } from '@/features/dashboard/components/TrendCharts'
import {
  allTime, bucketize, eachDay, isAllTime, LIST_PRESETS,
  localEndIso, localStartIso, parseDay, toDay, type Range,
} from '@/features/dashboard/lib/dateRange'
import type { MealLog, WorkoutLog } from '@/types'
import { ArrowLeft, Phone, Calendar, MapPin, PhoneCall, Play, X } from 'lucide-react'

/**
 * TEN rows a page, the same contract as the trainer detail tabs: one member's
 * logs, not a whole-gym roster, so the denser fifteen-row lists would bury the
 * reader. Local on purpose — `LIST_PAGE_SIZE` stays 15 for the list pages.
 */
const DETAIL_PAGE_SIZE = 10

type DetailTab = 'info' | 'overview' | 'workouts' | 'meals'

/**
 * The four tabs in strip order. Info is the default; the other three are the
 * progress windows, each one question about the same member.
 */
const TAB_LIST: { id: DetailTab; label: string }[] = [
  { id: 'info', label: 'Info' },
  { id: 'overview', label: 'Overview' },
  { id: 'workouts', label: 'Workout Log' },
  { id: 'meals', label: 'Food Intake' },
]

export default function MemberDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { data: member, isLoading } = useMember(id!)
  const updateMember = useUpdateMember()

  /**
   * Personal Information is editable. `editing` toggles the inputs; `form`
   * is seeded from the member on entry so a half-typed edit can be discarded
   * by toggling off without touching the server.
   */
  const [editing, setEditing] = useState(false)
  const [form, setForm] = useState({
    phone: '',
    date_of_birth: '',
    gender: '',
    address: '',
    emergency_contact_name: '',
    emergency_contact_phone: '',
  })
  const startEdit = () => {
    if (!member) return
    setForm({
      phone: member.phone ?? '',
      date_of_birth: member.date_of_birth ?? '',
      gender: member.gender ?? '',
      address: member.address ?? '',
      emergency_contact_name: member.emergency_contact_name ?? '',
      emergency_contact_phone: member.emergency_contact_phone ?? '',
    })
    setEditing(true)
  }
  const saveEdit = () => {
    if (!id) return
    updateMember.mutate({ id, ...form }, { onSuccess: () => setEditing(false) })
  }

  /**
   * One flat strip: Info plus the three progress windows — no intermediate
   * "Progress" level. Every pane keys off this single state.
   */
  const [tab, setTab] = useState<DetailTab>('info')

  /**
   * One page number + range + search per log. The two logs are independent
   * result sets with different totals, so page 2 of workouts must never leak
   * into meals — the same per-tab paging the trainer detail page uses.
   */
  const [workoutsPage, setWorkoutsPage] = useState(1)
  const [workoutsRange, setWorkoutsRange] = useState<Range>(() => allTime())
  const [workoutsSearch, setWorkoutsSearch] = useState('')
  const [mealsPage, setMealsPage] = useState(1)
  const [mealsRange, setMealsRange] = useState<Range>(() => allTime())
  const [mealsSearch, setMealsSearch] = useState('')
  /**
   * Overview's own window — its picker drives the three charts. The logs keep
   * separate ranges because they are separate paged result sets; this one
   * server-filters the stamps the charts bucket (All time sends no bounds).
   */
  const [overviewRange, setOverviewRange] = useState<Range>(() => allTime())
  useResetPageOnChange(setWorkoutsPage, id, workoutsRange.start, workoutsRange.end, workoutsSearch)
  useResetPageOnChange(setMealsPage, id, mealsRange.start, mealsRange.end, mealsSearch)

  /** The proof video / food photo currently open in the modal, else null. */
  const [selectedVideo, setSelectedVideo] = useState<WorkoutLog | null>(null)
  const [selectedPhoto, setSelectedPhoto] = useState<MealLog | null>(null)

  /**
   * Every `logged_at` for this member inside Overview's window, one fetch.
   * All three charts bucket the same array client-side, so Overview costs one
   * round trip, not three. Bounds go in the query so a narrow window is never
   * silently cut by the limit; All time sends none. The panes page their own.
   */
  const overviewAll = isAllTime(overviewRange)
  const { data: progressStamps } = useQuery({
    queryKey: ['member-progress-workouts', id, overviewRange.start, overviewRange.end],
    enabled: tab === 'overview' && !!id,
    queryFn: async () => {
      let q = supabase
        .from('workout_logs')
        .select('logged_at')
        .eq('member_id', id)
      if (!overviewAll) {
        q = q
          .gte('logged_at', localStartIso(overviewRange.start))
          .lte('logged_at', localEndIso(overviewRange.end))
      }
      const { data } = await q.order('logged_at', { ascending: true }).limit(2000)
      return (data ?? []) as { logged_at: string }[]
    },
  })

  /**
   * Every check-in day for this member inside Overview's window — the source
   * for the This Month card, which counts check-ins (not workouts). `check_in_date`
   * is already a local YYYY-MM-DD string, so it is bucketed as-is (no TZ shift).
   */
  const { data: checkinStamps } = useQuery({
    queryKey: ['member-progress-checkins', id, overviewRange.start, overviewRange.end],
    enabled: tab === 'overview' && !!id,
    queryFn: async () => {
      let q = supabase
        .from('attendance')
        .select('check_in_date')
        .eq('member_id', id)
      if (!overviewAll) {
        q = q
          .gte('check_in_date', overviewRange.start)
          .lte('check_in_date', overviewRange.end)
      }
      const { data } = await q.order('check_in_date', { ascending: true }).limit(2000)
      return (data ?? []) as { check_in_date: string }[]
    },
  })

  /**
   * This week (7 daily bars), this month (daily bars), growth over time
   * (monthly totals) — each window clipped to Overview's picked range, so the
   * picker on the tab row filters all three cards. On All time the clips are
   * no-ops (the start predates the data, the end is today), which reproduces
   * the fixed windows this replaced. Counting is by local day.
   *
   * Above the early returns on purpose: hooks cannot sit behind them, and this
   * memo only reads `progressStamps`, which is null-safe on its own.
   */
  const overview = useMemo(() => {
    const counts = new Map<string, number>()
    for (const r of progressStamps ?? []) {
      const day = toDay(new Date(r.logged_at))
      counts.set(day, (counts.get(day) ?? 0) + 1)
    }
    // Check-ins bucket by their own day string; a separate map so the workout
    // week chart and the check-in month chart never share a counter.
    const checkinCounts = new Map<string, number>()
    for (const r of checkinStamps ?? []) {
      const day = r.check_in_date
      checkinCounts.set(day, (checkinCounts.get(day) ?? 0) + 1)
    }
    const daily = (days: string[], from: Map<string, number>): TrendPoint[] =>
      days.map(day => ({
        key: day,
        label: day.slice(8),
        full: new Date(`${day}T00:00:00`).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }),
        value: from.get(day) ?? 0,
      }))
    const range = overviewRange
    const endDay = parseDay(range.end)
    const clip = (raw: string) => (raw < range.start ? range.start : raw)
    const weekStart = clip(toDay(new Date(endDay.getTime() - 6 * 86_400_000)))
    const monthStart = clip(toDay(new Date(endDay.getFullYear(), endDay.getMonth(), 1)))
    const growth: TrendPoint[] = bucketize(range, 'monthly').map(b => ({
      key: b.key,
      label: b.label,
      full: b.full,
      value: eachDay(b.start, b.end).reduce((s, d) => s + (counts.get(d) ?? 0), 0),
    }))
    return {
      week: daily(eachDay(weekStart, range.end), counts),
      month: daily(eachDay(monthStart, range.end), checkinCounts),
      growth,
    }
  }, [progressStamps, checkinStamps, overviewRange])

  const { data: address } = useQuery({
    queryKey: ['member-address', id],
    queryFn: async () => {
      const { data } = await supabase
        .from('addresses')
        .select('*')
        .eq('member_id', id)
        .maybeSingle()
      return data
    },
  })

  const { data: trainerAssignment } = useQuery({
    queryKey: ['member-trainer', id],
    queryFn: async () => {
      const { data } = await supabase
        .from('trainer_assignments')
        .select('*, profiles!trainer_assignments_trainer_id_fkey(full_name, email)')
        .eq('member_id', id)
        .eq('status', 'active')
        .maybeSingle()
      return data as any ?? null
    },
  })

  /**
   * `timestamptz` bounds, so the edges are local-midnight ISO instants — bare
   * 'YYYY-MM-DD' strings would read as UTC and clip a day in PH. All-time
   * sends NO bounds, the same convention the coach-feedback page uses.
   */
  const workoutsAll = isAllTime(workoutsRange)
  const { rows: workoutRows, total: workoutTotal, pageCount: workoutPageCount, isLoading: workoutsLoading } =
    usePagedTable<WorkoutLog>({
      table: 'workout_logs',
      select: '*',
      orderBy: [{ column: 'logged_at', ascending: false }, { column: 'id', ascending: false }],
      page: workoutsPage,
      pageSize: DETAIL_PAGE_SIZE,
      search: workoutsSearch,
      searchColumns: ['exercise_name', 'workout_name'],
      dateColumn: 'logged_at',
      from: workoutsAll ? undefined : localStartIso(workoutsRange.start),
      to: workoutsAll ? undefined : localEndIso(workoutsRange.end),
      eq: { member_id: id },
      enabled: tab === 'workouts' && !!id,
    })

  const mealsAll = isAllTime(mealsRange)
  const { rows: mealRows, total: mealTotal, pageCount: mealPageCount, isLoading: mealsLoading } =
    usePagedTable<MealLog>({
      table: 'meal_logs',
      select: '*',
      orderBy: [{ column: 'meal_time', ascending: false }, { column: 'id', ascending: false }],
      page: mealsPage,
      pageSize: DETAIL_PAGE_SIZE,
      search: mealsSearch,
      searchColumns: ['food_name', 'meal_type'],
      dateColumn: 'meal_time',
      from: mealsAll ? undefined : localStartIso(mealsRange.start),
      to: mealsAll ? undefined : localEndIso(mealsRange.end),
      eq: { member_id: id },
      enabled: tab === 'meals' && !!id,
    })

  /**
   * The height of ONE row is the body's height divided by the rows ACTUALLY on
   * screen, so a log pane fills its card edge to edge: a full ten-row page
   * stretches down to the footer, and a short page (six meals, five rows on the
   * last page) stretches its fewer rows instead of leaving a purple hole under
   * them. Empty and loading panes fall back to the ten-row count so the message
   * row stays ordinary instead of inflating to the whole card.
   *
   * The ceiling is lifted far off the hook's 52px default because 52 IS the gap
   * on a tall window: at 1920x1080 the budget is ~66px a row, and on a one-row
   * last page the contract says that row stretches, not that the card fills with
   * emptiness. `PeopleTable` centers cell content (`align-middle`, measured
   * padding capped at 12px), so a tall row reads as deliberate spacing. One
   * shared measurement still serves both logs - only one is mounted at a time.
   */
  const logRowsOnScreen =
    (tab === 'meals' ? mealRows.length : tab === 'workouts' ? workoutRows.length : 0) || DETAIL_PAGE_SIZE
  const [scrollRef, rowHeight] = useFitRowHeight<HTMLDivElement>({ count: logRowsOnScreen, max: 1000 })

  if (isLoading) return <div className="text-center py-8 text-fg-muted">Loading...</div>
  if (!member) return <div className="text-center py-8 text-fg-muted">Member not found</div>

  const structuredAddress = address ? [address.line1, address.line2, address.city, address.state, address.postal_code, address.country].filter(Boolean).join(', ') : null
  const fullAddress = structuredAddress || member.address || null

  const workoutName = (w: WorkoutLog) => w.workout_name || w.exercise_name
  const workoutWeight = (w: WorkoutLog) => w.weight ?? w.weight_kg
  const workoutMinutes = (w: WorkoutLog) =>
    w.duration_minutes ?? (w.duration_seconds != null ? Math.round(w.duration_seconds / 60) : null)

  const workoutColumns: PeopleColumn<WorkoutLog>[] = [
    { key: 'date', header: 'Date', render: w => <span className="whitespace-nowrap">{new Date(w.logged_at).toLocaleDateString()}</span> },
    { key: 'exercise', header: 'Exercise', render: w => <span className="font-medium text-fg-strong">{workoutName(w)}</span> },
    { key: 'weight', header: 'Weight', render: w => { const v = workoutWeight(w); return <span className="tabular-nums">{v != null ? `${v} kg` : '—'}</span> } },
    { key: 'duration', header: 'Duration', render: w => { const v = workoutMinutes(w); return <span className="tabular-nums">{v != null ? `${v} min` : '—'}</span> } },
    {
      key: 'total', header: 'Total',
      // kcal when the session recorded it; otherwise a volume summary
      // (sets x reps x weight) so a legacy row still shows something.
      render: w => {
        if (w.total_calories != null) return <span className="tabular-nums text-fg-strong">{w.total_calories} kcal</span>
        const vol = w.sets != null && w.reps != null && workoutWeight(w) != null
          ? w.sets * w.reps * (workoutWeight(w) as number)
          : null
        return <span className="tabular-nums text-fg-muted">{vol != null ? `${vol} kg·vol` : '—'}</span>
      },
    },
    {
      key: 'proof', header: 'Proof',
      render: w => w.proof_url ? (
        <button type="button" onClick={() => setSelectedVideo(w)} className="inline-flex items-center gap-1.5 text-accent-purple hover:underline cursor-pointer">
          <Play className="w-3.5 h-3.5" /> Watch
        </button>
      ) : <span className="text-fg-faint italic">No video</span>,
    },
  ]

  const mealColumns: PeopleColumn<MealLog>[] = [
    { key: 'date', header: 'Date', render: m => <span className="whitespace-nowrap">{new Date(m.meal_time).toLocaleDateString()}</span> },
    { key: 'meal', header: 'Meal', render: m => <span className="font-medium text-fg-strong capitalize">{m.meal_type}</span> },
    { key: 'food', header: 'Food', render: m => <span className="text-fg">{m.food_name}</span> },
    { key: 'kcal', header: 'Kcal', render: m => <span className="tabular-nums text-fg-strong">{m.calories != null ? m.calories : '—'}</span> },
    { key: 'protein', header: 'Protein', render: m => <span className="tabular-nums">{m.protein_g != null ? `${m.protein_g} g` : '—'}</span> },
    { key: 'carbs', header: 'Carbs', render: m => <span className="tabular-nums">{m.carbs_g != null ? `${m.carbs_g} g` : '—'}</span> },
    { key: 'fat', header: 'Fat', render: m => <span className="tabular-nums">{m.fat_g != null ? `${m.fat_g} g` : '—'}</span> },
    {
      key: 'photo', header: 'Photo',
      render: m => m.photo_url ? (
        <button
          type="button"
          onClick={() => setSelectedPhoto(m)}
          className="block cursor-pointer rounded-lg overflow-hidden border border-line hover:border-[#7C3AED]/60 transition-colors"
          aria-label={`View photo of ${m.food_name}`}
        >
          <img src={m.photo_url} alt={m.food_name} className="w-10 h-10 object-cover" loading="lazy" />
        </button>
      ) : <span className="text-fg-faint">—</span>,
    },
  ]

  const safeWorkoutsPage = Math.min(workoutsPage, workoutPageCount)
  const safeMealsPage = Math.min(mealsPage, mealPageCount)

  return (
    <div className="h-full min-h-0 flex flex-col gap-3">
      <button onClick={() => navigate('/members')} className="flex items-center gap-1 text-sm text-fg-muted hover:text-fg shrink-0">
        <ArrowLeft className="w-4 h-4" /> Back to Members
      </button>

      {/* Profile header */}
      <div className="glass-card p-4 rounded-xl shrink-0">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-full bg-gradient-to-br from-[#7C3AED]/30 to-[#C084FC]/30 flex items-center justify-center">
            <span className="text-xl font-bold text-accent-purple">
              {member.full_name.charAt(0)}
            </span>
          </div>
          <div>
            <div className="text-lg font-bold text-fg-strong">{member.full_name}</div>
            <p className="text-sm text-fg">{member.email}</p>
            <p className="text-xs font-mono text-fg-strong mt-1">{member.code}</p>
          </div>
        </div>
      </div>

      {/* One strip of four tabs. The date filter sits right-aligned on this
          same row and only on the three data tabs — Info has no time window.
          Bottom-aligned so the active underline still meets the rule. */}
      <div className="flex items-end justify-between gap-3 border-b border-line shrink-0">
        <div className="flex gap-1" role="tablist" aria-label="Member detail sections">
          {TAB_LIST.map(t => (
            <button
              key={t.id}
              role="tab"
              aria-selected={tab === t.id}
              onClick={() => setTab(t.id)}
              className={`px-4 py-2 text-sm font-medium transition-colors cursor-pointer ${tab === t.id
                ? 'text-accent-purple border-b-2 border-[#7C3AED] -mb-px'
                : 'text-fg-muted hover:text-fg-strong'
                }`}
            >
              {t.label}
            </button>
          ))}
        </div>
        {tab !== 'info' && (
          <DateRangePicker
            value={tab === 'overview' ? overviewRange : tab === 'workouts' ? workoutsRange : mealsRange}
            onChange={tab === 'overview' ? setOverviewRange : tab === 'workouts' ? setWorkoutsRange : setMealsRange}
            presets={LIST_PRESETS}
            className="shrink-0"
          />
        )}
      </div>

      {/* Trainer assignment */}
      {trainerAssignment && tab === 'info' && (
        <div className="glass-card p-4 rounded-xl">
          <h2 className="text-base font-semibold mb-3 text-fg-strong">Assigned Trainer</h2>
          <div className="flex items-center gap-3 cursor-pointer"
            onClick={() => navigate(`/trainers/${trainerAssignment.trainer_id}`)}
          >
            <div className="w-9 h-9 rounded-full bg-[#22C55E]/20 flex items-center justify-center">
              <span className="text-sm font-bold text-accent-green">
                {trainerAssignment.profiles?.full_name?.charAt(0)}
              </span>
            </div>
            <div>
              <p className="font-medium text-fg-strong">{trainerAssignment.profiles?.full_name}</p>
              <p className="text-xs text-fg">{trainerAssignment.profiles?.email}</p>
            </div>
          </div>
        </div>
      )}

      {/* Personal Info */}
      {tab === 'info' && (
      <div className="glass-card p-4 rounded-xl shrink-0">
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-base font-semibold text-fg-strong">Personal Information</h2>
          {editing ? (
            <div className="flex gap-2">
              <button onClick={() => setEditing(false)} className="px-3 py-1.5 text-xs rounded-lg border border-line text-fg-muted hover:text-fg-strong cursor-pointer transition-colors">Cancel</button>
              <button onClick={saveEdit} disabled={updateMember.isPending} className="px-3 py-1.5 text-xs rounded-lg bg-[#7C3AED] text-white hover:bg-[#6D28D9] disabled:opacity-50 cursor-pointer transition-colors">
                {updateMember.isPending ? 'Saving…' : 'Save'}
              </button>
            </div>
          ) : (
            <button onClick={startEdit} className="px-3 py-1.5 text-xs rounded-lg border border-line text-fg-muted hover:text-fg-strong hover:border-[#7C3AED]/50 cursor-pointer transition-colors">Edit</button>
          )}
        </div>
        {editing ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {([
              ['phone', 'Phone', 'text'],
              ['date_of_birth', 'Date of Birth', 'date'],
              ['gender', 'Gender', 'text'],
              ['address', 'Address', 'text'],
              ['emergency_contact_name', 'Emergency Contact Name', 'text'],
              ['emergency_contact_phone', 'Emergency Contact Phone', 'text'],
            ] as const).map(([key, label, type]) => (
              <label key={key} className="block">
                <span className="block text-xs text-fg-muted mb-1">{label}</span>
                <input
                  type={type}
                  value={form[key]}
                  onChange={e => setForm(f => ({ ...f, [key]: e.target.value }))}
                  className="w-full px-3 py-2 text-sm bg-page-deep border border-line rounded-lg text-fg-strong focus:outline-none focus:border-[#7C3AED]"
                />
              </label>
            ))}
          </div>
        ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          <div className="flex items-center gap-3">
            <Phone className="w-4 h-4 text-fg-muted" />
            <div>
              <p className="text-xs text-fg-muted">Phone</p>
              <p className="text-sm text-fg-strong">{member.phone || '—'}</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <Calendar className="w-4 h-4 text-fg-muted" />
            <div>
              <p className="text-xs text-fg-muted">Date of Birth</p>
              <p className="text-sm text-fg-strong">{member.date_of_birth || '—'}</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <div className="w-4 h-4 flex items-center justify-center text-fg-muted">
              <span className="text-xs font-bold">G</span>
            </div>
            <div>
              <p className="text-xs text-fg-muted">Gender</p>
              <p className="text-sm text-fg-strong capitalize">{member.gender || '—'}</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <MapPin className="w-4 h-4 text-fg-muted" />
            <div>
              <p className="text-xs text-fg-muted">Address</p>
              <p className="text-sm text-fg-strong">{fullAddress || '—'}</p>
            </div>
          </div>
        </div>
        )}
        {!editing && (
        <div className="border-t border-line mt-3 pt-3">
          <h3 className="text-sm font-semibold text-fg-strong mb-2">Emergency Contact</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div className="flex items-center gap-3">
              <PhoneCall className="w-4 h-4 text-fg-muted" />
              <div>
                <p className="text-xs text-fg-muted">Contact Name</p>
                <p className="text-sm text-fg-strong">{member.emergency_contact_name || '—'}</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <Phone className="w-4 h-4 text-fg-muted" />
              <div>
                <p className="text-xs text-fg-muted">Contact Phone</p>
                <p className="text-sm text-fg-strong">{member.emergency_contact_phone || '—'}</p>
              </div>
            </div>
          </div>
        </div>
        )}
      </div>
      )}

      {/* Overview: three charts, every window clipped to the picked range, the
          grid stretched to the pane so no space is left empty */}
      {tab === 'overview' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-3 flex-1 min-h-0 overflow-y-auto">
          <div className="glass-card p-4 rounded-xl flex flex-col">
            <h3 className="text-sm font-semibold text-fg-strong mb-2">This Week</h3>
            <div className="flex-1 min-h-[8rem]">
              <BarTrend points={overview.week} ariaLabel="Workouts this week" valueName="workouts" gradientId="memberWeekGrad" />
            </div>
          </div>
          <div className="glass-card p-4 rounded-xl flex flex-col">
            <h3 className="text-sm font-semibold text-fg-strong mb-2">This Month — Check-ins</h3>
            <div className="flex-1 min-h-[8rem]">
              <BarTrend points={overview.month} ariaLabel="Check-ins this month" valueName="check-ins" gradientId="memberMonthGrad" />
            </div>
          </div>
          <div className="glass-card p-4 rounded-xl lg:col-span-2 flex flex-col">
            <h3 className="text-sm font-semibold text-fg-strong mb-2">Growth Over Time</h3>
            <div className="flex-1 min-h-[10rem]">
              <GrowthAreaTrend points={overview.growth} ariaLabel="Workout growth over time" gradientId="memberGrowthGrad" />
            </div>
          </div>
        </div>
      )}

          {/* Workout Log: paged list with video proof; the date filter lives
              on the shared tab row above */}
          {tab === 'workouts' && (
            <div className="flex-1 min-h-0 flex flex-col">
              <div className="flex-1 min-h-0">
                <PeopleTable
                  title="Workout Log"
                  rows={workoutRows}
                  columns={workoutColumns}
                  rowKey={w => w.id}
                  isLoading={workoutsLoading}
                  emptyMessage={workoutTotal === 0 ? 'No workouts logged' : 'No workouts match this search'}
                  search={{ value: workoutsSearch, onChange: setWorkoutsSearch, placeholder: 'Search exercises…' }}
                  scrollRef={scrollRef}
                  rowHeight={rowHeight}
                  startIndex={(safeWorkoutsPage - 1) * DETAIL_PAGE_SIZE + 1}
                  footer={
                    <PaginationFooter
                      page={safeWorkoutsPage}
                      pageCount={workoutPageCount}
                      total={workoutTotal}
                      pageSize={DETAIL_PAGE_SIZE}
                      onPageChange={setWorkoutsPage}
                    />
                  }
                />
              </div>
            </div>
          )}

          {/* Food Intake: paged list with photo thumbnails; the date filter
              lives on the shared tab row above */}
          {tab === 'meals' && (
            <div className="flex-1 min-h-0 flex flex-col">
              <div className="flex-1 min-h-0">
                <PeopleTable
                  title="Food Intake"
                  rows={mealRows}
                  columns={mealColumns}
                  rowKey={m => m.id}
                  isLoading={mealsLoading}
                  emptyMessage={mealTotal === 0 ? 'No meals logged' : 'No meals match this search'}
                  search={{ value: mealsSearch, onChange: setMealsSearch, placeholder: 'Search foods…' }}
                  scrollRef={scrollRef}
                  rowHeight={rowHeight}
                  startIndex={(safeMealsPage - 1) * DETAIL_PAGE_SIZE + 1}
                  footer={
                    <PaginationFooter
                      page={safeMealsPage}
                      pageCount={mealPageCount}
                      total={mealTotal}
                      pageSize={DETAIL_PAGE_SIZE}
                      onPageChange={setMealsPage}
                    />
                  }
                />
              </div>
            </div>
          )}

      {/* Proof video modal: one player at a time, not ten inline preloads */}
      {selectedVideo?.proof_url && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4" onClick={() => setSelectedVideo(null)}>
          <div className="glass-card rounded-xl max-w-2xl w-full p-4" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-sm font-semibold text-fg-strong">{workoutName(selectedVideo)} — {new Date(selectedVideo.logged_at).toLocaleDateString()}</h3>
              <button onClick={() => setSelectedVideo(null)} aria-label="Close video" className="text-fg-muted hover:text-fg-strong transition-colors cursor-pointer">
                <X className="w-5 h-5" />
              </button>
            </div>
            <video controls preload="metadata" src={selectedVideo.proof_url} className="w-full rounded-lg max-h-[60vh] bg-black" />
          </div>
        </div>
      )}

      {/* Food photo modal */}
      {selectedPhoto?.photo_url && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4" onClick={() => setSelectedPhoto(null)}>
          <div className="glass-card rounded-xl max-w-2xl w-full p-4" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-sm font-semibold text-fg-strong">{selectedPhoto.food_name} — {new Date(selectedPhoto.meal_time).toLocaleDateString()}</h3>
              <button onClick={() => setSelectedPhoto(null)} aria-label="Close photo" className="text-fg-muted hover:text-fg-strong transition-colors cursor-pointer">
                <X className="w-5 h-5" />
              </button>
            </div>
            <img src={selectedPhoto.photo_url} alt={selectedPhoto.food_name} className="w-full rounded-lg max-h-[60vh] object-contain bg-black" />
          </div>
        </div>
      )}
    </div>
  )
}
