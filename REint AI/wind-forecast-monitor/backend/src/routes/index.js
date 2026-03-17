import { Router } from 'express'

const router = Router()

// These will be implemented in Phase 2
// Stubs are here so the server starts cleanly and endpoints return
// something useful during development

router.get('/actual-generation', (req, res) => {
  // TODO: validate query params, call ActualsModel
  res.status(501).json({ error: 'Not implemented yet' })
})

router.get('/forecast-generation', (req, res) => {
  // TODO: validate query params + horizon, call ForecastsModel
  res.status(501).json({ error: 'Not implemented yet' })
})

router.get('/combined-data', (req, res) => {
  // TODO: merge actuals with matched forecasts at given horizon
  res.status(501).json({ error: 'Not implemented yet' })
})

router.get('/data-availability', (req, res) => {
  // TODO: return date coverage info so the frontend knows what's cached
  res.status(501).json({ error: 'Not implemented yet' })
})

export default router
