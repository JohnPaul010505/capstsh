import { useState } from 'react'
import { usePredictions, useGeneratePredictions, useMembersSimple, type MemberOption } from '../hooks/usePredictions'
import { TrendingUp, TrendingDown, RefreshCw, Sparkles, AlertCircle, Info, ChevronDown, ShieldCheck, Database, Cpu } from 'lucide-react'
import StatusBadge from '@/components/StatusBadge'
import { MemberSelect } from '@/components/MemberSelect'

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

const signed = (n: number, digits = 1) => `${n > 0 ? '+' : ''}${n.toFixed(digits)}`

export default function PredictionsPage() {
  const [selectedMemberId, setSelectedMemberId] = useState('')
  const [aiResults, setAiResults] = useState<Forecast[] | null>(null)
  const [aiResultSource, setAiResultSource] = useState<'ai' | 'fallback' | null>(null)
  const [generating, setGenerating] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [showMethod, setShowMethod] = useState(false)

  const { data: predictions } = usePredictions()
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

  return (
    <div className="space-y-3">
      {/* --- Methodology: what is predicted, from what, and how --------------- */}
      <div className="glass-card rounded-xl overflow-hidden">
        <button
          onClick={() => setShowMethod((v) => !v)}
          className="w-full flex items-center justify-between px-4 py-3 text-left hover:bg-[#7C3AED]/5 transition-colors"
        >
          <span className="flex items-center gap-2 text-sm font-semibold text-fg-strong">
            <Info className="w-4 h-4 text-accent-purple" />
            How these predictions are measured
          </span>
          <ChevronDown className={`w-4 h-4 text-fg-muted transition-transform ${showMethod ? 'rotate-180' : ''}`} />
        </button>
        {showMethod && (
          <div className="px-4 pb-4 grid grid-cols-1 md:grid-cols-3 gap-3 text-xs text-fg-muted">
            <div className="bg-overlay-8 rounded-lg p-3">
              <p className="flex items-center gap-1.5 font-semibold text-fg mb-1.5">
                <Cpu className="w-3.5 h-3.5 text-accent-purple" /> What is predicted
              </p>
              <ul className="space-y-1 list-disc pl-4">
                <li><span className="text-fg">Body weight</span> — in kilograms</li>
                <li><span className="text-fg">Retention risk</span> — 0 to 1 score (higher = more likely to go inactive)</li>
              </ul>
              <p className="mt-1.5">Both project <span className="text-fg">30 days ahead</span> of the latest reading.</p>
              <p className="mt-1.5 text-fg-muted">
                Body fat is not forecast: no screen in the system records it, so there is nothing reliable to project from.
              </p>
            </div>
            <div className="bg-overlay-8 rounded-lg p-3">
              <p className="flex items-center gap-1.5 font-semibold text-fg mb-1.5">
                <Database className="w-3.5 h-3.5 text-accent-blue" /> What data is used
              </p>
              <ul className="space-y-1 list-disc pl-4">
                <li><span className="text-fg">body_measurements.weight_kg</span> — the weight and the date it was recorded</li>
                <li><span className="text-fg">attendance</span> — check-in timestamps from QR scans</li>
              </ul>
              <p className="mt-1.5">
                Both are entered by the <span className="text-fg">member</span> (onboarding and BMI check-ins). Trainers and admins
                only view the results — they do not set or edit prediction inputs.
              </p>
            </div>
            <div className="bg-overlay-8 rounded-lg p-3">
              <p className="flex items-center gap-1.5 font-semibold text-fg mb-1.5">
                <ShieldCheck className="w-3.5 h-3.5 text-accent-green" /> How it is calculated
              </p>
              <ul className="space-y-1 list-disc pl-4">
                <li><span className="text-fg">Weight:</span> least-squares linear regression over the <span className="text-fg">actual dates</span> of the weigh-ins, projected 30 days forward</li>
                <li><span className="text-fg">Safety cap:</span> at most ±5% body weight in 30 days (the clinical safe rate is ~0.5–1% per week), so a short or noisy trend cannot produce an impossible number</li>
                <li><span className="text-fg">Minimum data:</span> 3+ weigh-ins spanning 7+ days, otherwise no forecast is produced</li>
                <li><span className="text-fg">Retention risk:</span> 60% check-in frequency + 20% falling trend + 20% time since last visit</li>
                <li><span className="text-fg">Confidence:</span> fit quality (R²) × how much data the fit used, capped at 95%</li>
              </ul>
            </div>
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
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
        <div className="flex items-start gap-2 p-3 rounded-xl border border-[#F59E0B]/30 bg-[#F59E0B]/10 text-sm text-fg">
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
        <div className="bg-gradient-to-r from-[#7C3AED]/10 to-[#3B82F6]/10 p-4 rounded-xl border border-[#7C3AED]/30 shadow-sm">
          <div className="flex items-center justify-between mb-3 gap-2 flex-wrap">
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
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
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

      <div className="glass-card rounded-xl overflow-hidden flex flex-col min-h-0">
        <div className="px-4 py-3 border-b border-line">
          <h2 className="font-semibold text-fg-strong">Recent Predictions</h2>
          <p className="text-xs text-fg-muted mt-0.5">
            Forecasts stored in the <span className="text-fg">predictions</span> table by the AI service. The
            <span className="text-fg"> basis</span> column shows the readings each number came from; re-generating the same
            member replaces that member's row for the same metric and target date instead of duplicating it.
          </p>
        </div>
        {predictions?.length === 0 ? (
          <div className="text-center py-6 text-fg-muted">No predictions yet. Select a member and click Generate.</div>
        ) : (
          <div className="overflow-x-auto flex-1">
            <table className="w-full">
              <thead>
                <tr className="border-b border-line bg-overlay-5">
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Member</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Metric</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Predicted</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Basis</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Confidence</th>
                </tr>
              </thead>
              <tbody>
                {predictions?.map(p => {
                  const isRiskRow = p.metric_name === 'retention_risk'
                  const row = {
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
                  } as Forecast
                  return (
                    <tr key={p.id} className="border-b border-line-soft last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                      <td className="px-3 py-2 text-sm font-medium text-fg-strong">{p.profiles?.full_name}</td>
                      <td className="px-3 py-2 text-sm text-fg">{METRIC_LABELS[p.metric_name] ?? p.metric_name}</td>
                      <td className="px-3 py-2 text-sm text-fg">
                        {p.predicted_value} {p.unit ?? ''}
                        {!isRiskRow && p.current_value != null && (
                          <span className="text-fg-muted text-xs"> (from {p.current_value})</span>
                        )}
                      </td>
                      <td className="px-3 py-2 text-xs text-fg-muted">
                        {p.data_points ? basisText(row) : 'recorded before provenance tracking'}
                        {p.clamped && <span className="text-accent-amber"> · capped</span>}
                      </td>
                      <td className="px-3 py-2">
                        {isRiskRow ? (
                          <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${RISK_STYLES[riskLevel(p.predicted_value)]}`}>
                            {riskLevel(p.predicted_value)} risk
                          </span>
                        ) : (
                          <StatusBadge status={(p.confidence ?? 0) >= 0.7 ? 'high' : (p.confidence ?? 0) >= 0.4 ? 'medium' : 'low'} />
                        )}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
