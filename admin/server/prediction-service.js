import { config } from 'dotenv'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import express from 'express'
import { createClient } from '@supabase/supabase-js'
import { createPredictionHandler } from './predictionEngine.js'

config({ path: resolve(dirname(fileURLToPath(import.meta.url)), '../.env'), quiet: true })
const { VITE_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = process.env
if (!VITE_SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) throw new Error('Missing forecast database configuration')
const db = createClient(VITE_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false, autoRefreshToken: false } })
const app = express()
app.use(express.json({ limit: '16kb' }))
app.get('/health', (_, res) => res.json({ status: 'ok', engine: 'regression-and-retention' }))
app.post('/api/ai/predictions', (req, res, next) => {
  res.setHeader('x-forecast-source', 'ai')
  createPredictionHandler(db)(req, res).catch(next)
})
app.use((error, req, res, next) => {
  console.error('Prediction service failed:', error.message)
  res.status(500).json({ error: 'Could not calculate or save predictions' })
})
app.listen(Number(process.env.PREDICTION_PORT || 8001), '127.0.0.1', () => console.log('Prediction service ready on localhost:8001'))
