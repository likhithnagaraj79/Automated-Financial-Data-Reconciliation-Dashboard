import axios from 'axios'

const BASE_URL = process.env.BMRS_BASE_URL || 'https://data.elexon.co.uk/bmrs/api/v1'

const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

// Retry with exponential backoff — handles rate limits and transient server errors
async function fetchWithRetry(url, params, maxRetries = 3) {
  let lastError

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const res = await axios.get(url, {
        params,
        timeout: 30000,
        headers: { Accept: 'application/json' },
      })
      return res.data
    } catch (err) {
      lastError = err
      const status = err.response?.status

      if (status === 429) {
        // respect rate limit — wait longer each time
        const wait = 5000 * (attempt + 1)
        console.warn(`[BMRS] Rate limited. Waiting ${wait}ms (attempt ${attempt + 1}/${maxRetries})`)
        await sleep(wait)
      } else if (status >= 500) {
        const wait = 1000 * Math.pow(2, attempt)
        console.warn(`[BMRS] Server error ${status}. Retry in ${wait}ms`)
        await sleep(wait)
      } else {
        throw err // 4xx errors aren't worth retrying (except 429 above)
      }
    }
  }

  throw lastError
}

// Fetch actual half-hourly wind generation from FUELHH dataset
// startDate / endDate: 'YYYY-MM-DD'
export async function fetchActualGeneration(startDate, endDate) {
  console.log(`[BMRS] Fetching FUELHH actuals: ${startDate} → ${endDate}`)

  const data = await fetchWithRetry(`${BASE_URL}/datasets/FUELHH/stream`, {
    settlementDateFrom: startDate,
    settlementDateTo: endDate,
    fuelType: 'WIND',
  })

  if (!Array.isArray(data)) {
    throw new Error(`Unexpected FUELHH response: ${JSON.stringify(data).slice(0, 200)}`)
  }

  // defensive filter — the API should only return WIND, but let's be sure
  const wind = data.filter(
    (r) => r.fuelType === 'WIND' && r.startTime && r.generation != null
  )

  console.log(`[BMRS] Got ${wind.length} actual wind records`)

  return wind.map((r) => ({
    start_time: r.startTime,
    settlement_date: r.settlementDate || null,
    settlement_period: r.settlementPeriod || null,
    generation: r.generation,
    fuel_type: 'WIND',
  }))
}

// Fetch wind generation forecasts from WINDFOR dataset
// publishFrom / publishTo: ISO datetime strings ('2025-01-01T00:00:00Z')
export async function fetchWindForecasts(publishFrom, publishTo) {
  console.log(`[BMRS] Fetching WINDFOR forecasts published: ${publishFrom} → ${publishTo}`)

  const data = await fetchWithRetry(`${BASE_URL}/datasets/WINDFOR/stream`, {
    publishDateTimeFrom: publishFrom,
    publishDateTimeTo: publishTo,
  })

  if (!Array.isArray(data)) {
    throw new Error(`Unexpected WINDFOR response: ${JSON.stringify(data).slice(0, 200)}`)
  }

  const valid = data.filter(
    (r) => r.startTime && r.publishTime && r.generation != null
  )

  console.log(`[BMRS] Got ${valid.length} forecast records`)

  return valid.map((r) => ({
    start_time: r.startTime,
    publish_time: r.publishTime,
    generation: r.generation,
  }))
}
