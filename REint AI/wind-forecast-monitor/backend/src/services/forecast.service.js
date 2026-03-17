import { subtractHours, toStartOfDayUTC, toEndOfDayUTC } from '../utils/dateUtils.js'
import { getActualsByDateRange, upsertActuals } from '../models/actuals.model.js'
import { getForecastsForRange, upsertForecasts } from '../models/forecasts.model.js'
import { fetchActualGeneration, fetchWindForecasts } from './bmrs.service.js'

// Ensure actuals are cached for the date range.
// If nothing is in the DB for this range, fetch from BMRS and store.
// TODO: smarter gap-detection for partially-cached ranges
export async function ensureActuals(startDate, endDate) {
  const startISO = toStartOfDayUTC(startDate)
  const endISO = toEndOfDayUTC(endDate)

  const existing = getActualsByDateRange(startISO, endISO)

  if (existing.length === 0) {
    const records = await fetchActualGeneration(startDate, endDate)
    if (records.length > 0) {
      upsertActuals(records)
    }
    return getActualsByDateRange(startISO, endISO)
  }

  return existing
}

// Ensure forecasts are cached for the date range.
// Fetches forecasts published in [startDate - 48h, endDate] so that all
// possible forecast horizons (0–48h) are covered for every actual.
export async function ensureForecasts(startDate, endDate) {
  const startISO = toStartOfDayUTC(startDate)
  const endISO = toEndOfDayUTC(endDate)

  const existing = getForecastsForRange(startISO, endISO)

  if (existing.length === 0) {
    // publishTime window: a forecast for startDate could have been published
    // up to 48 hours earlier — so we go back 48h to cover max horizon
    const publishFrom = subtractHours(startISO, 48)
    const publishTo = endISO

    const records = await fetchWindForecasts(publishFrom, publishTo)
    if (records.length > 0) {
      upsertForecasts(records)
    }
    return getForecastsForRange(startISO, endISO)
  }

  return existing
}

// Match each actual to the best forecast at the given horizon.
//
// "Best forecast" for a given startTime T at horizon H = the most recently
// published forecast where:
//   - forecast.start_time === T  (targets the same half-hour)
//   - forecast.publish_time <= T - H  (was published at least H hours earlier)
//
// We do this in-memory (one DB read for all forecasts, then group + match)
// to avoid N+1 queries for large date ranges.
export function buildCombinedData(actuals, horizonHours, allForecasts) {
  if (actuals.length === 0) return []

  // Group forecasts by startTime for O(1) lookup per actual
  const forecastMap = new Map()
  for (const f of allForecasts) {
    if (!forecastMap.has(f.start_time)) {
      forecastMap.set(f.start_time, [])
    }
    forecastMap.get(f.start_time).push(f)
  }

  return actuals.map((actual) => {
    const cutoff = subtractHours(actual.start_time, horizonHours)

    // All forecasts for this half-hour that were published before the cutoff
    const candidates = (forecastMap.get(actual.start_time) || []).filter(
      (f) => f.publish_time <= cutoff
    )

    let forecast = null
    if (candidates.length > 0) {
      // pick the most recently published one — it has the most information
      forecast = candidates.reduce((best, curr) =>
        curr.publish_time > best.publish_time ? curr : best
      )
    }

    return {
      start_time: actual.start_time,
      actual_generation: actual.generation,
      forecast_generation: forecast?.generation ?? null,
      forecast_publish_time: forecast?.publish_time ?? null,
      has_forecast: forecast !== null,
    }
  })
}
