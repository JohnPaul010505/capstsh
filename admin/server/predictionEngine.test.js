import { test } from 'node:test'
import assert from 'node:assert/strict'
import { forecastTrend, retentionForecast } from './predictionEngine.js'

test('forecast uses elapsed dates and limits predicted change', () => {
  const result = forecastTrend([70, 72, 76], ['2026-09-01', '2026-09-08', '2026-09-29'], 30)
  assert.equal(result.sufficient, true)
  assert.ok(result.predicted_value <= 76 * 1.05)
  assert.ok(result.predicted_value >= 76)
  assert.equal(result.span_days, 28)
})
test('short history cannot produce a trend forecast', () => {
  assert.equal(forecastTrend([70], ['2026-10-22'], 30).sufficient, false)
  assert.equal(forecastTrend([70, 71, 72], ['2026-10-20', '2026-10-21', '2026-10-22'], 30).sufficient, false)
})
test('longer absences and declining attendance increase retention risk', () => {
  assert.ok(retentionForecast([0.5, 0.5, 0.5, 0.5], 30).score > retentionForecast([0.5, 0.5, 0.5, 0.5], 0).score)
  assert.ok(retentionForecast([1, 0.75, 0.5, 0.25], 7).score > retentionForecast([0.25, 0.5, 0.75, 1], 7).score)
})
