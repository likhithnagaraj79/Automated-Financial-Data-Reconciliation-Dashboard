import express from 'express'
import cors from 'cors'
import dotenv from 'dotenv'
import cron from 'node-cron'
import { initDb } from './utils/db.js'
import apiRoutes from './routes/index.js'
import { fetchActualGeneration, fetchWindForecasts } from './services/bmrs.service.js'
import { upsertActuals } from './models/actuals.model.js'
import { upsertForecasts } from './models/forecasts.model.js'
import { subtractHours, todayStr, yesterdayStr } from './utils/dateUtils.js'

dotenv.config()

const app = express()
const PORT = process.env.PORT || 3000

app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:5173',
}))

app.use(express.json())

// Init DB tables on startup
initDb()

// Health check — Render uses this to confirm the service is alive
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() })
})

app.use('/api', apiRoutes)

// Global error handler — catches anything that slips through route handlers
app.use((err, _req, res, _next) => {
  console.error(err.stack)
  res.status(500).json({ error: 'Something went wrong' })
})

// Background cron: refresh the last 2 days of data every 6 hours
// Keeps recent actuals and forecasts up-to-date without hammering the API
const CRON_SCHEDULE = process.env.CRON_SCHEDULE || '0 */6 * * *'
cron.schedule(CRON_SCHEDULE, async () => {
  const today = todayStr()
  const yesterday = yesterdayStr()

  console.log(`[cron] Refreshing data for ${yesterday} → ${today}`)

  try {
    const actuals = await fetchActualGeneration(yesterday, today)
    if (actuals.length > 0) upsertActuals(actuals)

    // forecasts published up to 48h before yesterday could affect today's horizon logic
    const publishFrom = subtractHours(`${yesterday}T00:00:00.000Z`, 48)
    const publishTo = `${today}T23:59:59.999Z`
    const forecasts = await fetchWindForecasts(publishFrom, publishTo)
    if (forecasts.length > 0) upsertForecasts(forecasts)

    console.log(
      `[cron] Done — ${actuals.length} actuals, ${forecasts.length} forecasts refreshed`
    )
  } catch (e) {
    // don't crash the server on cron failure — log and move on
    console.error('[cron] Refresh failed:', e.message)
  }
})

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`)
  console.log(`Health: http://localhost:${PORT}/health`)
  console.log(`Cron: ${CRON_SCHEDULE}`)
})

export default app
