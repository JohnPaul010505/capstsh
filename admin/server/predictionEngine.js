// Shared, source-based forecasting engine used by the service and fallback.
export function createPredictionHandler(adminClient) {
 return async (req, res) => {
 const { member_id, days_ahead = 30 } = req.body
 if (!member_id || !Number.isInteger(days_ahead) || days_ahead < 1 || days_ahead > 365) return res.status(400).json({error: 'A member and horizon of 1–365 days are required'})
  // The offline fallback uses the same maths and guardrails as the AI service.
  const results = []
  const notes = []

  const { data: measurements, error: measurementError } = await adminClient
    .from('body_measurements')
    .select('weight_kg, measured_at')
    .eq('member_id', member_id)
    .order('measured_at', { ascending: true })
  if (measurementError) throw measurementError

  if (measurements && measurements.length) {
    const weights = measurements.map((m) => m.weight_kg)
    if (weights.some((v) => v !== null && v !== undefined)) {
      // Weight only, matching the AI service: body fat is not forecast because
      // no screen in the system captures it.
      const pred = forecastTrend(weights, measurements.map((m) => m.measured_at), days_ahead)
      if (!pred.sufficient) {
        if (pred.data_points === 1 && pred.current_value > 0) {
          results.push({
            prediction_type: 'weight',
            current_value: pred.current_value,
            predicted_value: pred.current_value,
            unit: 'kg',
            days_ahead,
            confidence: 0,
            data_points: 1,
            span_days: 0,
            date_from: pred.date_from,
            date_to: pred.date_to,
            method: 'baseline-only',
            sufficient: false,
            note: 'Starting weight only — this is the member’s baseline, not a trend forecast. A trend needs 3 weigh-ins spanning at least 7 days.',
          })
        } else {
          notes.push(`Weight: ${pred.reason}`)
        }
      } else {
        results.push({
          prediction_type: 'weight',
          current_value: pred.current_value,
          predicted_value: pred.predicted_value,
          unit: 'kg',
          days_ahead,
          confidence: pred.confidence,
          data_points: pred.data_points,
          span_days: pred.span_days,
          date_from: pred.date_from,
          date_to: pred.date_to,
          daily_rate: pred.daily_rate,
          change: pred.change,
          clamped: pred.clamped,
          method: pred.method,
        })
      }
    }
  }

  const { data: attendance, error: attendanceError } = await adminClient
    .from('attendance')
    .select('check_in_time')
    .eq('member_id', member_id)
    .order('check_in_time', { ascending: false })
    .order('check_in_time', { ascending: true })
  if (attendanceError) throw attendanceError

  const visits = (attendance ?? [])
    .map((a) => new Date(a.check_in_time))
    .filter((d) => Number.isFinite(d.getTime()))
  const now = Date.now()
  const first = visits.length ? new Date(Math.min(...visits.map((d) => d.getTime()))) : null
  const last = visits.length ? new Date(Math.max(...visits.map((d) => d.getTime()))) : null
  const completedWeeks = first ? Math.max(0, Math.floor((now - first.getTime()) / 604800000)) : 0
  const counts = Array(completedWeeks).fill(0)
  for (const visit of visits) {
    const week = first ? Math.floor((visit.getTime() - first.getTime()) / 604800000) : -1
    if (week >= 0 && week < completedWeeks) counts[week] += 1
  }
  const rates = counts.map((count) => Math.min(1, count / 7))
  if (completedWeeks < 4) {
    results.push({
      prediction_type: 'retention_risk',
      current_value: 0,
      predicted_value: 0,
      unit: 'risk score (0-1)',
      days_ahead: 30,
      confidence: 0,
      data_points: completedWeeks,
      method: 'insufficient-history',
      sufficient: false,
      note: first
        ? `Not enough attendance history yet: ${completedWeeks} of 4 completed weeks. Retention risk will appear after 4 full weeks.`
        : 'No check-ins recorded yet. Retention estimates start after the first check-in and 4 completed weeks.',
    })
  } else {
    const daysSince = Math.max(0, Math.floor((now - last.getTime()) / 86400000))
    const risk = retentionForecast(rates, daysSince)
    results.push({
      prediction_type: 'retention_risk',
      current_value: Math.round(rates[rates.length - 1] * 100) / 100,
      predicted_value: risk.score,
      unit: 'risk score (0-1)',
      days_ahead: 30,
      // Trust in the estimate (attendance history depth) — not the risk score,
      // which used to render "high risk" as "high confidence".
      confidence: risk.confidence,
      data_points: rates.length,
      daily_rate: risk.weekly_rate,
      method: 'weighted-heuristic',
      sufficient: true,
      note:
        `60% check-in frequency + 20% falling trend + 20% recency ` +
        `(last visit ${daysSince}d ago) - risk level ${risk.risk}`,
    })
  }

  if (results.length === 0) {
    return res.status(404).json({
      detail: 'Not enough data for predictions. ' + (notes.length ? notes.join(' ') : 'Log measurements and attendance first.'),
    })
  }

  // Keep offline estimates in the same history as AI-service results. The
  // dashboard count and Recent Predictions then reflect every successful run.
  const predictedDate = new Date(Date.now() + Number(days_ahead) * 86400000).toISOString().slice(0, 10)
  for (const result of results) {
    if (result.sufficient === false || result.method === 'baseline-only') continue
    const row = {
      member_id,
      metric_name: result.prediction_type,
      predicted_value: result.predicted_value,
      predicted_date: predictedDate,
      confidence: result.confidence,
    }
    const basis = {
      current_value: result.current_value,
      unit: result.unit,
      data_points: result.data_points,
      span_days: result.span_days,
      date_from: result.date_from || null,
      date_to: result.date_to || null,
      daily_rate: result.daily_rate,
      change: result.change,
      clamped: result.clamped,
      method: result.method,
      note: result.note,
    }
    let { error } = await adminClient.from('predictions').insert({ ...row, ...basis })
    if (error && (error.code === 'PGRST204' || /column .* not found|schema cache/i.test(error.message ?? ''))) {
      const retry = await adminClient.from('predictions').insert(row)
      error = retry.error
    }
    if (error) {
      console.error('Could not save local prediction:', error)
      return res.status(500).json({ error: 'Forecast was calculated but could not be saved to Recent Predictions.' })
    }
  }

  res.json(results)
 }
}

const MIN_POINTS = 3
const MIN_SPAN_DAYS = 7
const FULL_SAMPLE_POINTS = 5
const FULL_SAMPLE_DAYS = 28
const MAX_CONFIDENCE = 0.95 // a forecast is never reported as certain
const MAX_WEIGHT_CHANGE_PCT = 0.05
const MIN_PLAUSIBLE_VALUE = 0.5
const RETENTION_FULL_WEEKS = 6
const RETENTION_W_FREQUENCY = 0.6
const RETENTION_W_TREND = 0.2
const RETENTION_W_RECENCY = 0.2

const round2 = (v) => Math.round(v * 100) / 100
const round4 = (v) => Math.round(v * 10000) / 10000

function toDayNumber(stamp) {
  if (stamp === null || stamp === undefined) return null
  const t = stamp instanceof Date ? stamp.getTime() : new Date(stamp).getTime()
  return Number.isNaN(t) ? null : t / 86400000
}

/// Least-squares trend over *elapsed days* (not row indices), clamped to a
/// physiologically plausible rate, and only forecast once there is enough
/// history to mean anything.
function forecastTrend(values, stamps, daysAhead) {
  const points = []
  values.forEach((raw, i) => {
    const v = typeof raw === 'number' ? raw : parseFloat(raw)
    if (!Number.isFinite(v) || v <= 0) return
    const stamp = stamps && i < stamps.length ? stamps[i] : null
    points.push({ value: v, day: toDayNumber(stamp), stamp })
  })
  if (points.length === 0) {
    return { sufficient: false, reason: 'no measurements recorded yet', data_points: 0, current_value: 0 }
  }
  const useDates = points.length >= 2 && points.every((p) => p.day !== null)
  if (useDates) points.sort((a, b) => a.day - b.day)
  const ys = points.map((p) => p.value)
  const xs = points.map((p, i) => (useDates ? p.day : i))
  const n = ys.length
  const current = ys[n - 1]
  const spanDays = useDates ? xs[n - 1] - xs[0] : 0
  const basis = {
    current_value: round2(current),
    data_points: n,
    span_days: Math.round(spanDays),
    date_from: points[0].stamp ?? null,
    date_to: points[n - 1].stamp ?? null,
    method: 'ols-linear-regression',
  }
  if (n < 2) {
    return { ...basis, sufficient: false, reason: `only ${n} measurement logged - at least 2 are needed` }
  }
  if (n < MIN_POINTS || (useDates && spanDays < MIN_SPAN_DAYS)) {
    return {
      ...basis,
      sufficient: false,
      reason: `needs at least ${MIN_POINTS} weigh-ins over ${MIN_SPAN_DAYS}+ days (has ${n} over ${Math.round(spanDays)}d)`,
    }
  }
  const xMean = xs.reduce((a, b) => a + b, 0) / n
  const yMean = ys.reduce((a, b) => a + b, 0) / n
  let num = 0
  let den = 0
  for (let i = 0; i < n; i++) {
    const dx = xs[i] - xMean
    num += dx * (ys[i] - yMean)
    den += dx * dx
  }
  const slope = den !== 0 ? num / den : 0
  const intercept = yMean - slope * xMean
  let ssRes = 0
  let ssTot = 0
  for (let i = 0; i < n; i++) {
    const fit = intercept + slope * xs[i]
    ssRes += (ys[i] - fit) ** 2
    ssTot += (ys[i] - yMean) ** 2
  }
  const r2 = ssTot !== 0 ? Math.max(0, Math.min(1, 1 - ssRes / ssTot)) : 0
  const rawPrediction = intercept + slope * (xs[n - 1] + daysAhead)
  // Body weight may move at most +/-5% in the horizon: the clinical safe rate is
  // roughly 0.5-1% of body weight per week.
  const low = Math.max(current * (1 - MAX_WEIGHT_CHANGE_PCT), MIN_PLAUSIBLE_VALUE)
  const high = current * (1 + MAX_WEIGHT_CHANGE_PCT)
  const predicted = Math.min(Math.max(rawPrediction, low), high)
  const sampleFactor = Math.min(1, (n - 1) / (FULL_SAMPLE_POINTS - 1))
  const spanFactor = useDates ? Math.min(1, spanDays / FULL_SAMPLE_DAYS) : 0.5
  return {
    ...basis,
    sufficient: true,
    predicted_value: round2(predicted),
    change: round2(predicted - current),
    clamped: Math.abs(predicted - rawPrediction) > 1e-9,
    confidence: round2(Math.max(0, Math.min(MAX_CONFIDENCE, r2 * sampleFactor * spanFactor))),
    r2: Math.round(r2 * 1000) / 1000,
    trend: slope > 0 ? 'up' : slope < 0 ? 'down' : 'flat',
    daily_rate: useDates ? round4(slope) : null,
  }
}

/// Mirrors retention_risk(): frequency credit minus falling trend minus recency.
function retentionForecast(rates, daysSince) {
  if (!rates.length) return { score: 0.5, confidence: 0, risk: 'unknown', weekly_rate: null, data_points: 0 }
  const avg = rates.reduce((a, b) => a + b, 0) / rates.length
  let trend = 0
  if (rates.length > 1) {
    const xMean = (rates.length - 1) / 2
    let num = 0
    let den = 0
    for (let i = 0; i < rates.length; i++) {
      const dx = i - xMean
      num += dx * (rates[i] - avg)
      den += dx * dx
    }
    trend = den !== 0 ? num / den : 0
  }
  // Falling attendance and longer absences must increase risk.
  const raw = (1 - avg) * RETENTION_W_FREQUENCY
    + Math.min(1, Math.max(0, -trend)) * RETENTION_W_TREND
    + Math.min(1, Math.max(0, daysSince) / 30) * RETENTION_W_RECENCY
  // Round before banding: classifying the raw value labelled a 0.4004 risk as
  // "medium" for a perfectly consistent attendee.
  const score = round2(Math.max(0, Math.min(1, raw)))
  return {
    score,
    confidence: round2(Math.max(0.3, Math.min(1, rates.length / RETENTION_FULL_WEEKS))),
    risk: score > 0.7 ? 'high' : score > 0.4 ? 'medium' : 'low',
    weekly_rate: Math.round(avg * 1000) / 1000,
    data_points: rates.length,
  }
}


export { forecastTrend, retentionForecast }
