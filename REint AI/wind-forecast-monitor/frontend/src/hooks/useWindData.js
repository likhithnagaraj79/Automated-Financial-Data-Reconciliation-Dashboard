import { useState, useEffect, useCallback, useRef } from 'react'
import { fetchCombinedData } from '../services/api.js'

export function useWindData(startDate, endDate, horizon) {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const abortRef = useRef(null)

  const fetchData = useCallback(async () => {
    if (!startDate || !endDate) return

    // cancel any in-flight request before starting a new one
    if (abortRef.current) {
      abortRef.current.abort()
    }
    abortRef.current = new AbortController()

    setLoading(true)
    setError(null)

    try {
      const result = await fetchCombinedData(
        startDate,
        endDate,
        horizon,
        abortRef.current.signal
      )
      setData(result)
    } catch (e) {
      // ignore cancellations — they're intentional
      if (e.name === 'CanceledError' || e.name === 'AbortError') return

      const msg =
        e.response?.data?.error ||
        e.response?.data?.detail ||
        e.message ||
        'Failed to load data'
      setError(msg)
    } finally {
      setLoading(false)
    }
  }, [startDate, endDate, horizon])

  useEffect(() => {
    fetchData()
    return () => abortRef.current?.abort()
  }, [fetchData])

  return { data, loading, error, refetch: fetchData }
}
