import { useState } from 'react'
import { usePredictions, useGeneratePredictions, useMembersSimple, type MemberOption } from '../hooks/usePredictions'
// No Info/ChevronDown/Cpu/ShieldCheck/Database: they were only ever used by the
// "How these predictions are measured" block, which is gone. `noUnusedLocals`
// is on, so leaving them imported would fail the build rather than just sit
// there looking untidy.
import { TrendingUp, TrendingDown, RefreshCw, Sparkles, AlertCircle } from 'lucide-react'
import StatusBadge from '@/components/StatusBadge'
import { MemberSelect } from '@/components/MemberSelect'
import DateRangePicker from '@/components/DateRangePicker'
import RecordsTable, { type RecordsColumn } from '@/components/RecordsTable'
import { allTime, LIST_PRESETS, type Range } from '@/features/dashboard/lib/dateRange'

/** One forecast line from POST /api/ai/predictions (ai-service/routers/predictions.py). */
interface Forecast {
  prediction_type: string
  current_value: number
  predicted_value: number
  unit: string
  days_ahead: number
  confidence: number
  data_points?: number | null
  span_days?: number | null
  date_from?: string | null
  date_to?: string | null
  daily_rate?: number | null
  change?: number | null
  clamped?: boolean | null
  method?: string | null
  note?: string | null
}

const METRIC_LABELS: Record<string, string> = {
  weight: 'Body weight',
  body_fat: 'Body fat',
  retention_risk: 'Retention risk',
}

const isRisk = (f: Forecast) => f.prediction_type === 'retention_risk'

/** Risk bands match services/ml.py retention_risk() thresholds. */
function riskLevel(score: number): 'low' | 'medium' | 'high' {
  if (score > 0.7) return 'high'
  if (score > 0.4) return 'medium'
  return 'low'
}

const RISK_STYLES: Record<string, string> = {
  low: 'bg-[#22C55E]/15 text-accent-green',
  medium: 'bg-[#F59E0B]/15 text-accent-amber',
  high: 'bg-[#EF4444]/15 text-accent-red',
}

const pct = (v: number) => `${Math.round(v * 100)}%`

function confidenceLabel(c: number, points?: number | null): string {
  if (c >= 0.7) return points && points >= 5 ? 'high — strong fit, good sample' : 'high — strong fit, limited sample'
  if (c >= 0.4) return 'medium — usable, keep logging'
  return 'low — too little history to trust yet'
}

function monthLabel(value?: string | null): string {
  if (!value) return '?'
  const d = new Date(value)
  return Number.isNaN(d.getTime())
    ? '?'
    : d.toLocaleDateString(undefined, { month: 'short', year: 'numeric' })
}

/** "8 weigh-ins, Jan 2026 – Jul 2026 (186 days)" — the evidence behind a number. */
function basisText(f: Forecast): string {
  if (isRisk(f)) {
    const weeks = f.data_points ?? 0
    return `${weeks} week${weeks === 1 ? '' : 's'} of check-ins${f.daily_rate != null ? ` · avg ${f.daily_rate.toFixed(2)} visits/day` : ''}`
  }
  const points = f.data_points ?? 0
  const range = `${monthLabel(f.date_from)} – ${monthLabel(f.date_to)}`
  const span = f.span_days ? ` (${f.span_days} days)` : ''
  return `${points} weigh-in${points === 1 ? '' : 's'}, ${range}${span}`
}

/**
 * A stored `predictions` row shaped as the `Forecast` the formatters above
 * already speak.
 *
 * It used to be built inline inside the `<tbody>` map, which meant `basisText`
 * had to be re-derived per row just to print one cell - and, more importantly,
 * meant the search box had nothing to match against, because there was no row
 * object outside the table to ask. Lifting it here gives both the column
 * renderer and `searchFields` the same view of the row.
 */
function toForecast(p: any): Forecast {
  return {
    prediction_type: p.metric_name,
    current_value: p.current_value ?? 0,
    predicted_value: p.predicted_value ?? 0,
    unit: p.unit ?? '',
    days_ahead: 30,
    confidence: p.confidence ?? 0,
    data_points: p.data_points,
    span_days: p.span_days,
    date_from: p.date_from,
    date_to: p.date_to,
    daily_rate: p.daily_rate,
    change: p.change,
    clamped: p.clamped,
  }
}

const signed = (n: number, digits = 1) => `${n > 0 ? '+' : ''}${n.toFixed(digits)}`

/**
 * Two views of the page, in the same order Notifications uses: the thing you
 * came here to do, then the record of what you did.
 *
 * `generate` opens first and holds the three cards - totals, the generator, the
 * high-confidence count - AND the "Last Generated Results" panel. `recent` is the
 * stored predictions table on its own.
 *
 * The results panel used to live on `recent`, and a successful generate used to
 * switch tabs to show it there. Both are wrong for the same reason: the numbers
 * you just asked for belong next to the button that produced them, not three
 * seconds later on another tab. So the panel stays on `generate` and generating
 * no longer navigates. It also stays on this tab for the case it was really
 * written for - when the AI service is down it returns an estimate that is NOT
 * written to the `predictions` table, so this panel is the only place those
 * numbers exist at all.
 *
 * There was a third view. "Prediction History" re-sorted the same 50 rows by
 * `created_at` instead of by metric, which read as a second, separate record
 * set while being the same query - and the page already had a third, fourth
 * thing to read in the "How these predictions are measured" block above them.
 * Both are gone.
 *
 * Tabs rather than routes on purpose, for the same reason the QR page uses them:
 * the header renders the page title, and a `/predictions/recent` sub-route would
 * have no chrome of its own to distinguish it.
 */
const PREDICTION_VIEWS = [
  { id: 'generate', label: 'Generate' },
  { id: 'recent', label: 'Recent Predictions' },
] as const

export default function PredictionsPage() {
  const [view, setView] = useState<(typeof PREDICTION_VIEWS)[number]['id']>('generate')
  const [selectedMemberId, setSelectedMemberId] = useState('')
  const [aiResults, setAiResults] = useState<Forecast[] | null>(null)
  const [aiResultSource, setAiResultSource] = useState<'ai' | 'fallback' | null>(null)
  const [generating, setGenerating] = useState(false)
  const [error, setError] = useState<string | null>(null)
  // Owned here rather than inside RecordsTable, which is a controlled input.
  const [search, setSearch] = useState('')
  // The window the RECENT list is read through, opened on the whole dataset so
  // the page lands on exactly the 50 rows it always did. It belongs to that
  // list alone: the picker is hidden over on Generate. The two Generate KPI
  // cards deliberately report the WHOLE table instead of this window, so that a
  // range chosen over here cannot silently change two headline counts on a tab
  // that carries no control to explain or undo them.
  const [range, setRange] = useState<Range>(() => allTime())

  // `undefined` on Generate, the picked window on Recent. `usePredictions`
  // treats an absent range as all-time and sends no bounds at all, which is both
  // the cheaper query and the one that leaves the seeded totals intact.
  const queryRange = view === 'recent' ? range : undefined
  const { data: predictions, isLoading: predictionsLoading } = usePredictions(queryRange)
  const { data: members } = useMembersSimple()
  const generateMutation = useGeneratePredictions()

  const generatePredictions = async () => {
    if (!selectedMemberId) return
    setGenerating(true)
    setAiResults(null)
    setAiResultSource(null)
    setError(null)
    try {
      const result: { data: any; source: 'ai' | 'fallback' } = await generateMutation.mutateAsync({ memberId: selectedMemberId, daysAhead: 30 })
      setAiResults((Array.isArray(result.data) ? result.data : (result.data.results ?? result.data)) as Forecast[])
      setAiResultSource(result.source)
      // Deliberately NO tab switch here. This used to jump to `recent` on
      // success, because that was where the results panel rendered. The panel
      // now lives on THIS tab, so switching would hide the numbers the admin
      // just asked for. Errors do not switch either: the banner explaining them
      // lives on the Generate view.
    } catch (err) {
      // A 404 here is the "needs more weigh-ins" case, not a crash — surface the
      // service's own wording instead of a generic alert.
      setError(err instanceof Error ? err.message : 'Failed to generate predictions')
    } finally {
      setGenerating(false)
    }
  }

  const memberOptions: { id: string; label: string }[] = (members ?? []).map((m: MemberOption) => ({
    id: m.id,
    label: `${m.full_name} (${m.code ?? '—'}) — ${m.email}`,
  }))
  const selectedMember = members?.find(m => m.id === selectedMemberId)

  const predictionRows = predictions ?? []

  // `leading-5` throughout: `RecordsTable` budgets 44px a row, and a row whose
  // cell renders at its natural 46px makes the measured page size lie by
  // exactly the difference - the body then scrolls a few pixels with no
  // explanation, which is the failure this whole table is meant to end.
  const predictionColumns: RecordsColumn<any>[] = [
    {
      key: 'member',
      header: 'Member',
      render: p => <span className="font-medium text-fg-strong leading-5">{p.profiles?.full_name}</span>,
    },
    {
      key: 'metric',
      header: 'Metric',
      render: p => <span className="text-fg leading-5">{METRIC_LABELS[p.metric_name] ?? p.metric_name}</span>,
    },
    {
      key: 'predicted',
      header: 'Predicted',
      render: p => (
        <span className="text-fg whitespace-nowrap leading-5">
          {p.predicted_value} {p.unit ?? ''}
          {!isRisk(toForecast(p)) && p.current_value != null && (
            <span className="text-fg-muted text-xs"> (from {p.current_value})</span>
          )}
        </span>
      ),
    },
    {
      key: 'basis',
      header: 'Basis',
      /* `leading-4`, not `leading-5`, and this is not cosmetic. A line box's
         height is the MAXIMUM ascent plus the MAXIMUM descent of everything on
         it - not the tallest total. So a 12px span carrying the same 20px
         line-height as the 14px strut does not contribute 20px: its smaller
         font puts its descent further below the baseline, and the line box
         comes to 22px. That is 2px over the 44px row budget on every row,
         which makes the measured page size too large and scrolls the body by
         15px with nothing to explain it. `leading-4` keeps the 12px look and
         puts the line box back at 16px, inside the strut. */
      render: p => (
        <span className="text-xs text-fg-muted leading-4">
          {p.data_points ? basisText(toForecast(p)) : 'recorded before provenance tracking'}
          {p.clamped && <span className="text-accent-amber"> · capped</span>}
        </span>
      ),
    },
    {
      key: 'confidence',
      header: 'Confidence',
      render: p => (isRisk(toForecast(p)) ? (
        /* No `leading-5` here, deliberately. `py-0.5` already makes the badge
           20px (16px line + 4px), which is the row budget; adding a 20px line
           box on top of 4px of padding makes it 24px, every row becomes 47px
           against `RecordsTable`'s 44px, and the measured page size is wrong by
           3px a row - which shows up as a body that scrolls with no visible
           cause. `StatusBadge` on the other branch carries no leading either,
           for the same reason. */
        <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${RISK_STYLES[riskLevel(p.predicted_value)]}`}>
          {riskLevel(p.predicted_value)} risk
        </span>
      ) : (
        <StatusBadge status={(p.confidence ?? 0) >= 0.7 ? 'high' : (p.confidence ?? 0) >= 0.4 ? 'medium' : 'low'} />
      )),
    },
  ]

  return (
    <div className="h-full min-h-0 flex flex-col gap-3">
      {/* View switch, at the TOP and `shrink-0`, so it stays put whichever
          view is showing. The panel below it is the only `flex-1` child of
          this column: the table has to be able to MEASURE its page size
          against the height it is actually given, which is why nothing else
          here is allowed to grow.

          The date filter rides on this same row, right-aligned, rather than
          getting a toolbar of its own - so it costs no vertical space at all -
          but it is shown on the RECENT tab only, the same rule the Notifications
          page follows. Over on Generate this chip would filter a list that is
          not on screen and move nothing there, because the two KPI cards on
          that tab report the whole table rather than a window of it; a picker
          beside them would look load-bearing and be inert.

          Hiding it is also what keeps the Generate numbers stable. They read the
          all-time query (`queryRange` above), so an admin who narrows the
          window over here and switches back does not watch two headline counts
          change to numbers that tab can neither explain nor undo. */}
      <div className="flex flex-wrap items-center gap-1.5 shrink-0">
        <div role="tablist" aria-label="Prediction sections" className="flex flex-wrap items-center gap-1.5">
          {PREDICTION_VIEWS.map(v => (
            <button
              key={v.id}
              type="button"
              role="tab"
              aria-selected={view === v.id}
              onClick={() => setView(v.id)}
              className={`px-3.5 py-2 rounded-xl text-sm transition-colors ${
                view === v.id
                  ? 'bg-[#7C3AED] text-white'
                  : 'bg-overlay-8 border border-line text-fg-muted hover:text-fg-strong hover:border-[#7C3AED]/40'
              }`}
            >
              {v.label}
            </button>
          ))}
        </div>
        {view === 'recent' && (
          <DateRangePicker
            value={range}
            onChange={setRange}
            presets={LIST_PRESETS}
            className="ml-auto"
          />
        )}
      </div>

      <div role="tabpanel" aria-label="Prediction content" className="flex-1 min-h-0 min-w-0 flex flex-col gap-3">
        {view === 'generate' && (
          <>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-3 shrink-0">
              <div className="glass-card p-4 rounded-xl">
                <div className="flex items-center gap-2 text-sm text-fg-muted mb-1">
                  <TrendingUp className="w-4 h-4 text-[#22C55E]" />
                  <span>Total Predictions</span>
                </div>
                <p className="text-xl font-bold text-fg-strong">{predictions?.length ?? 0}</p>
                <p className="text-xs text-fg-muted mt-1">
                  Stored forecast rows in the <span className="text-fg">predictions</span> table — one per metric per member
                  (weight and retention risk). Latest 50 shown.
                </p>
              </div>
              <div className="glass-card p-4 rounded-xl relative z-30">
                <div className="flex items-center gap-2 text-sm text-fg-muted mb-1">
                  <Sparkles className="w-4 h-4 text-accent-purple" />
                  <span>Generate New</span>
                </div>
                <div className="flex items-center gap-2">
                  <MemberSelect
                    options={memberOptions}
                    value={selectedMemberId}
                    onChange={setSelectedMemberId}
                    placeholder="Select member..."
                    className="flex-1 min-w-0"
                    /* 987 members and no way to narrow them. The label carries the
                       name, the member code and the email, so one box finds them
                       by any of the three instead of scrolling the roster. */
                    searchable
                  />
                  <button
                    onClick={generatePredictions}
                    disabled={!selectedMemberId || generating}
                    className="flex items-center gap-1 px-3 py-2 text-sm bg-gradient-to-r from-[#7C3AED] to-[#3B82F6] text-white rounded-lg hover:opacity-90 disabled:opacity-50 transition-opacity"
                  >
                    {generating ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Sparkles className="w-4 h-4" />}
                    {generating ? 'Generating...' : 'Generate'}
                  </button>
                </div>
              </div>
              <div className="glass-card p-4 rounded-xl">
                <div className="flex items-center gap-2 text-sm text-fg-muted mb-1">
                  <TrendingDown className="w-4 h-4 text-[#F59E0B]" />
                  <span>High Confidence</span>
                </div>
                <p className="text-xl font-bold text-fg-strong">
                  {predictions?.filter(p => p.confidence >= 0.7).length ?? 0}
                </p>
                <p className="text-xs text-fg-muted mt-1">Confidence &gt;= 70%</p>
              </div>
            </div>

            {error && (
              <div className="flex items-start gap-2 p-3 rounded-xl border border-[#F59E0B]/30 bg-[#F59E0B]/10 text-sm text-fg shrink-0">
                <AlertCircle className="w-4 h-4 text-accent-amber shrink-0 mt-0.5" />
                <div>
                  <p className="font-medium text-fg-strong">No forecast produced</p>
                  <p className="text-xs text-fg-muted mt-0.5">{error}</p>
                  <p className="text-xs text-fg-muted mt-1">
                    Predictions need history to be meaningful — the service will not invent a number from too few readings.
                  </p>
                </div>
              </div>
            )}

            {aiResults && aiResults.length > 0 && (
              /* CAPPED, and it scrolls itself. A plain JS comment rather than a JSX
                 one, because this position is an EXPRESSION - the `&&` operand - not
                 JSX children, and a JSX comment there is a syntax error.
                 This panel only exists after a Generate, but it renders one card per
                 metric per member, and on a 768px window that is easily taller than
                 everything else on this tab put together. Unbounded it would push
                 this column past the viewport, which is the exact failure the
                 `overflow-hidden` main was hiding before.

                 It lives here rather than over on `recent` because these are the
                 numbers the admin just asked for, and the button that produced them
                 is two cards above this panel. */
              <div className="bg-gradient-to-r from-[#7C3AED]/10 to-[#3B82F6]/10 p-4 rounded-xl border border-[#7C3AED]/30 shadow-sm shrink-0 max-h-[30vh] flex flex-col min-h-0">
                <div className="flex items-center justify-between mb-3 gap-2 flex-wrap shrink-0">
                  <h2 className="text-base font-semibold text-fg-strong">
                    Last Generated Results — {selectedMember?.full_name ?? 'Member'}
                  </h2>
                  {aiResultSource === 'fallback' && (
                    <div className="flex items-center gap-1 px-2 py-1 text-xs rounded-full bg-[#F59E0B]/15 text-[#F59E0B]">
                      <AlertCircle className="w-3.5 h-3.5 shrink-0" />
                      <span>AI service offline — local estimate, not persisted</span>
                    </div>
                  )}
                </div>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3 overflow-y-auto min-h-0">
                  {aiResults.map((r, i) => {
                    const level = riskLevel(r.predicted_value)
                    return (
                      <div key={i} className="bg-overlay-8 p-4 rounded-lg border border-line shadow-sm">
                        <p className="text-sm font-medium text-fg">{METRIC_LABELS[r.prediction_type] ?? r.prediction_type}</p>

                        {isRisk(r) ? (
                          <>
                            <p className="text-xl font-bold text-fg-strong mt-1">
                              {r.predicted_value.toFixed(2)}
                              <span className="text-xs font-normal text-fg-muted ml-1.5">risk score</span>
                            </p>
                            <p className="text-xs text-fg-muted mt-0.5">
                              {r.note ?? 'Check-in frequency, trend and recency'}
                            </p>
                            <div className="mt-2 flex items-center gap-2 flex-wrap">
                              <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${RISK_STYLES[level]}`}>
                                {level} risk
                              </span>
                              <span className="text-[11px] text-fg-muted">data confidence {pct(r.confidence)}</span>
                            </div>
                          </>
                        ) : (
                          <>
                            <p className="text-xl font-bold text-fg-strong mt-1">
                              {r.current_value} <span className="text-fg-muted text-sm">&rarr;</span> {r.predicted_value}
                              <span className="text-xs font-normal text-fg-muted ml-1">{r.unit}</span>
                            </p>
                            <p className="text-xs text-fg-muted mt-0.5">
                              in {r.days_ahead} days ({r.change != null ? `${signed(r.change)} ${r.unit}` : '—'}) ·{' '}
                              {basisText(r)}
                              {r.daily_rate != null && ` · trend ${signed(r.daily_rate, 2)} ${r.unit}/day`}
                            </p>
                            {r.clamped && (
                              <p className="text-[11px] text-accent-amber mt-1">
                                Trend capped to a safe range (±5% weight / ±3 body-fat points in 30 days)
                              </p>
                            )}
                            <div className="mt-2 flex items-center gap-2 flex-wrap">
                              <StatusBadge status={r.confidence >= 0.7 ? 'high' : r.confidence >= 0.4 ? 'medium' : 'low'} />
                              <span className="text-[11px] text-fg-muted">{pct(r.confidence)} — {confidenceLabel(r.confidence, r.data_points)}</span>
                            </div>
                          </>
                        )}
                      </div>
                    )
                  })}
                </div>
              </div>
            )}
          </>
        )}

        {view === 'recent' && (
            <RecordsTable
              title="Recent Predictions"
              subtitle="Forecasts stored in the predictions table by the AI service. The basis column shows the readings each number came from; re-generating the same member replaces that member's row for the same metric and target date instead of duplicating it."
              columns={predictionColumns}
              rows={predictionRows}
              rowKey={p => p.id}
              searchFields={p => [
                p.profiles?.full_name,
                METRIC_LABELS[p.metric_name] ?? p.metric_name,
                basisText(toForecast(p)),
              ]}
              searchPlaceholder="Search by member or metric…"
              searchValue={search}
              onSearchChange={setSearch}
              isLoading={predictionsLoading}
              emptyMessage={predictionRows.length === 0
                ? 'No predictions yet. Select a member and click Generate.'
                : 'No predictions match this search'}
            />
        )}
      </div>
    </div>
  )
}
