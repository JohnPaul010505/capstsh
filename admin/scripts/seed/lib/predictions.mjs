// Pure generator for the predictions dataset (Task 5, part 2).
//
// This does NOT invent numbers. Every row is produced by the same maths the
// live service uses (ai-service/services/ml.py), so the seeded rows are exactly
// what the app itself would have written, and migration 0032's database guards
// (`predictions_weight_clamp_chk`, `predictions_confidence_chk`) pass:
//
//   weight  — OLS over the member's real body_measurements.weight_kg history,
//             forecast at last reading + 30 days, clamped to +/-5% of the
//             current value (floor 0.5 kg), confidence =
//             r2 * sample_factor * span_factor capped at MAX_CONFIDENCE (0.95).
//   retention_risk — the transparent weighted heuristic:
//             score = 1 - (avg_rate*0.6 + max(0,-trend)*0.2 + recency*0.2)
//             where avg_rate is the mean weekly attendance rate,
//             trend the least-squares slope of that rate, and
//             recency = min(1, days_since_last_visit/30).
//             Confidence is data sufficiency, max(0.3, min(1, weeks/6)) — which
//             legitimately reaches 1.0, and 0032 deliberately exempts this
//             metric from the 95% cap.
//
// Two constraints shape the output:
//  * body_fat is never forecast. PredictionsPage filters those rows out
//    (`.neq('metric_name','body_fat')`) and the service stopped producing them,
//    so none are generated.
//  * weight needs real weigh-ins. Only 26 members have body_measurements, so
//    weight rows exist for exactly those; retention_risk works from attendance
//    and covers a much wider slice of the roster.
//
// IDs: uuid('3e01a007', n) — continuing attendance (…003), memberships (…004),
// assignments (…005), feedback (…006).
import { makeRand, uuid, localDate } from './common.mjs'

export const PREDICTION_ID_PREFIX = '3e01a007'

// Mirrors of the constants in ai-service/services/ml.py. Kept as literals (not
// imported) so this seed stays runnable without the Python service present.
export const MAX_CONFIDENCE = 0.95
export const MAX_WEIGHT_CHANGE_PCT = 0.05
export const MIN_PLAUSIBLE_VALUE = 0.5
export const FULL_SAMPLE_POINTS = 5
export const FULL_SAMPLE_DAYS = 28
export const MIN_POINTS = 2
export const MIN_SPAN_DAYS = 7
export const RETENTION_W_FREQUENCY = 0.6
export const RETENTION_W_TREND = 0.2
export const RETENTION_W_RECENCY = 0.2
export const RETENTION_FULL_WEEKS = 6
export const RISK_HIGH_ABOVE = 0.7
export const RISK_MEDIUM_ABOVE = 0.4
export const HORIZON_DAYS = 30

const DAY = 86400000
// How many members get a retention-risk forecast. The page reads the newest 50
// rows, so this is sized to keep a broad spread in view while staying legible.
export const RETENTION_TARGET = 320

const round2 = (n) => Math.round(n * 100) / 100
const round3 = (n) => Math.round(n * 1000) / 1000
const round4 = (n) => Math.round(n * 10000) / 10000

/**
 * Ordinary least squares of y on x, plus R^2. Returns slope/intercept/r2.
 * Mirrors sklearn's LinearRegression + score() for a 1-feature fit.
 */
export function ols(xs, ys) {
  const n = xs.length
  const meanX = xs.reduce((a, b) => a + b, 0) / n
  const meanY = ys.reduce((a, b) => a + b, 0) / n
  let sxy = 0
  let sxx = 0
  let syy = 0
  for (let i = 0; i < n; i++) {
    const dx = xs[i] - meanX
    const dy = ys[i] - meanY
    sxy += dx * dy
    sxx += dx * dx
    syy += dy * dy
  }
  const slope = sxx === 0 ? 0 : sxy / sxx
  const intercept = meanY - slope * meanX
  const r2 = sxx === 0 || syy === 0 ? 0 : (sxy * sxy) / (sxx * syy)
  return { slope, intercept, r2 }
}

/**
 * Weight forecast for one member, from their real weigh-in history.
 * Returns null when the history is too thin — the service refuses to invent a
 * number in that case ("needs at least 2 weigh-ins over 7+ days"), and so do we.
 *
 * @param {Array<{weight:number, day:string}>} readings ascending by day
 */
export function forecastWeight(readings) {
  if (!readings.length) return null
  const sorted = [...readings].sort((a, b) => (a.day < b.day ? -1 : 1))
  const ys = sorted.map((r) => r.weight)
  // Days since epoch as the regression x-axis (ml.py passes measured_at and
  // regresses on the resulting day offsets, which is equivalent up to a shift).
  const xs = sorted.map((r) => Date.parse(`${r.day}T00:00:00Z`) / DAY)
  const n = ys.length
  const current = ys[n - 1]
  const spanDays = Math.round(xs[n - 1] - xs[0])

  if (n < MIN_POINTS) return { sufficient: false, data_points: n, span_days: spanDays, current_value: round2(current) }
  if (spanDays < MIN_SPAN_DAYS) {
    return { sufficient: false, data_points: n, span_days: spanDays, current_value: round2(current) }
  }

  const { slope, intercept, r2 } = ols(xs, ys)
  const horizon = xs[n - 1] + HORIZON_DAYS
  const rawPrediction = slope * horizon + intercept

  const low = Math.max(current * (1 - MAX_WEIGHT_CHANGE_PCT), MIN_PLAUSIBLE_VALUE)
  const high = current * (1 + MAX_WEIGHT_CHANGE_PCT)
  const predicted = Math.min(Math.max(rawPrediction, low), high)
  const clamped = Math.abs(predicted - rawPrediction) > 1e-9

  const sampleFactor = Math.min(1, (n - 1) / (FULL_SAMPLE_POINTS - 1))
  const spanFactor = Math.min(1, spanDays / FULL_SAMPLE_DAYS)
  const confidence = round2(Math.max(0, Math.min(MAX_CONFIDENCE, r2 * sampleFactor * spanFactor)))

  return {
    sufficient: true,
    current_value: round2(current),
    predicted_value: round2(predicted),
    change: round2(predicted - current),
    clamped,
    confidence,
    data_points: n,
    span_days: spanDays,
    date_from: sorted[0].day,
    date_to: sorted[n - 1].day,
    daily_rate: round4(slope),
    method: 'ols-linear-regression',
    r2: round3(r2),
    trend: slope > 0 ? 'up' : slope < 0 ? 'down' : 'flat',
  }
}

/**
 * Retention-risk forecast for one member, from their weekly attendance rates.
 *
 * @param {number[]} weeklyRates ascending, each min(1, check-ins/7)
 * @param {number}   daysSince    days since the member's last visit
 */
export function forecastRetentionRisk(weeklyRates, daysSince) {
  const rates = weeklyRates.filter((r) => r != null).map(Number)
  if (!rates.length) {
    return { score: 0.5, confidence: 0, data_points: 0, weekly_rate: null, method: 'weighted-heuristic', risk: 'unknown' }
  }
  const avgRate = rates.reduce((a, b) => a + b, 0) / rates.length
  // Least-squares slope of the rate series against week index (np.polyfit deg 1).
  const trend = rates.length > 1
    ? ols(rates.map((_, i) => i), rates).slope
    : 0
  const recency = Math.min(1, daysSince / 30)
  const score = 1 - (
    avgRate * RETENTION_W_FREQUENCY
    + Math.max(0, -trend) * RETENTION_W_TREND
    + recency * RETENTION_W_RECENCY
  )
  const clampedScore = round2(Math.max(0, Math.min(1, score)))
  const weeks = rates.length
  const confidence = round2(Math.max(0.3, Math.min(1, weeks / RETENTION_FULL_WEEKS)))

  return {
    score: clampedScore,
    // Classify the ROUNDED score, matching ml.py — classifying the raw value
    // let a 0.4004 risk display as "medium".
    risk: clampedScore > RISK_HIGH_ABOVE ? 'high' : clampedScore > RISK_MEDIUM_ABOVE ? 'medium' : 'low',
    confidence,
    data_points: weeks,
    weekly_rate: round3(avgRate),
    method: 'weighted-heuristic',
    days_since: daysSince,
  }
}

/**
 * Assemble the predictions rows.
 *
 * @param {Map<string, Array<{weight:number, day:string}>>} weightsByMember
 *   real body_measurements.weight_kg history per member id
 * @param {Array<{memberId:string, weeklyRates:number[], daysSince:number}>} attendance
 *   the member's most recent 30 check-ins, bucketed into weeks exactly as
 *   ai-service/routers/predictions.py does
 * @param {{ seed?: number, today?: string }} [opts]
 */
export function buildPredictions(weightsByMember, attendance, opts = {}) {
  const { randInt } = makeRand(opts.seed ?? 20261001)
  const asOf = opts.today ?? localDate(new Date())
  const rows = []

  // --- weight: only for members with a real, sufficient weigh-in history ----
  let skipped = 0
  for (const [memberId, readings] of weightsByMember) {
    const f = forecastWeight(readings)
    if (!f || !f.sufficient) { skipped++; continue }
    rows.push({
      member_id: memberId,
      metric_name: 'weight',
      predicted_value: f.predicted_value,
      // 30 days past the latest reading, matching the service's horizon.
      predicted_date: addDays(f.date_to, HORIZON_DAYS),
      confidence: f.confidence,
      current_value: f.current_value,
      unit: 'kg',
      data_points: f.data_points,
      span_days: f.span_days,
      date_from: f.date_from,
      date_to: f.date_to,
      daily_rate: f.daily_rate,
      change: f.change,
      clamped: f.clamped,
      method: f.method,
      note: `${f.data_points} weigh-ins over ${f.span_days} days — trend is ${f.trend} at ${f.daily_rate} kg/day.`,
      // The forecast is "as of" the last measurement; the row is written when an
      // admin reviews it, so created_at trails the history slightly.
      created_at: new Date(`${addDays(f.date_to, randInt(1, 10))}T10:00:00+08:00`).toISOString(),
      _basis: { r2: f.r2, trend: f.trend },
    })
  }

  // --- retention risk: from attendance, the widest-coverage metric -----------
  // Score every candidate first, then stratify the panel by band.
  //
  // Sorting by recency alone does NOT work: the only members who reach the
  // "low" band are the churned cohort (lapsed AND historically high-frequency),
  // and they are by definition the LEAST recent. A recency-ordered take would
  // exclude them all and land the panel back on two bands. So: score, group,
  // then take a proportional slice of each band up to RETENTION_TARGET.
  const scored = []
  for (const a of attendance) {
    if (!a.weeklyRates.length) continue
    const r = forecastRetentionRisk(a.weeklyRates, a.daysSince)
    if (!r.data_points) continue
    scored.push({ a, r })
  }
  const groups = { low: [], medium: [], high: [] }
  for (const s of scored) groups[s.r.risk].push(s)
  // Target mix: enough low and medium that the page's band filter has real
  // options, with high as the majority — which matches a gym's real shape.
  const MIX = { low: 0.18, medium: 0.32, high: 0.5 }
  const take = []
  for (const band of ['low', 'medium', 'high']) {
    const want = Math.min(groups[band].length, Math.round(RETENTION_TARGET * MIX[band]))
    take.push(...groups[band].slice(0, want))
  }

  const bands = { low: 0, medium: 0, high: 0 }
  for (const { a, r } of take) {
    const r = forecastRetentionRisk(a.weeklyRates, a.daysSince)
    if (!r.data_points) continue
    bands[r.risk]++
    rows.push({
      member_id: a.memberId,
      metric_name: 'retention_risk',
      predicted_value: r.score,
      predicted_date: addDays(asOf, HORIZON_DAYS),
      // Data sufficiency, NOT the risk score — ml.py is explicit that a
      // high-risk member must not read as "high confidence". This metric is
      // exempt from 0032's 0.95 cap and may legitimately be 1.0.
      confidence: r.confidence,
      current_value: r.weekly_rate ?? 0.5,
      unit: 'risk score (0-1)',
      data_points: r.data_points,
      daily_rate: r.weekly_rate,
      method: r.method,
      note:
        `60% check-in frequency + 20% falling trend + 20% recency ` +
        `(last visit ${r.days_since}d ago) - risk level ${r.risk}`,
      created_at: new Date(`${asOf}T09:00:00+08:00`).toISOString(),
      _basis: { risk: r.risk, days_since: r.days_since },
    })
  }

  rows.sort((a, b) => (a.created_at < b.created_at ? -1 : 1))
  rows.forEach((r, i) => { r.id = uuid(PREDICTION_ID_PREFIX, i) })

  return { rows, asOf, bands, skippedWeights: skipped }
}

export const addDays = (iso, n) =>
  new Date(Date.parse(`${iso}T00:00:00Z`) + n * DAY).toISOString().slice(0, 10)
