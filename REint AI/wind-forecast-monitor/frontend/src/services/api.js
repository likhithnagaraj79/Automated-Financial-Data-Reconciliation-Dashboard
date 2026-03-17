import axios from 'axios'

// In dev, Vite proxies /api → backend (vite.config.js)
// In prod, set VITE_API_BASE_URL to the backend URL
const BASE_URL = import.meta.env.VITE_API_BASE_URL || ''

const client = axios.create({
  baseURL: BASE_URL,
  timeout: 60000, // data fetches can take a while on first load
})

export async function fetchCombinedData(start, end, horizon, signal) {
  const res = await client.get('/api/combined-data', {
    params: { start, end, horizon },
    signal,
  })
  return res.data
}

export async function fetchActualGeneration(start, end, signal) {
  const res = await client.get('/api/actual-generation', {
    params: { start, end },
    signal,
  })
  return res.data
}

export async function fetchDataAvailability(start, end) {
  const res = await client.get('/api/data-availability', {
    params: { start, end },
  })
  return res.data
}
