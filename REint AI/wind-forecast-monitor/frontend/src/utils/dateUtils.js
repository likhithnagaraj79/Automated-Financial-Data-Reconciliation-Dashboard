export const MIN_DATE = '2025-01-01'

export function todayStr() {
  return new Date().toISOString().slice(0, 10)
}

export function daysAgo(n) {
  return new Date(Date.now() - n * 86400000).toISOString().slice(0, 10)
}

// Format ISO string for chart tooltip — UK local time
export function formatDateTime(isoStr) {
  if (!isoStr) return ''
  try {
    return new Date(isoStr).toLocaleString('en-GB', {
      timeZone: 'Europe/London',
      day: '2-digit',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
    })
  } catch {
    return isoStr
  }
}

// Shorter format for x-axis ticks
export function formatDateTick(isoStr) {
  if (!isoStr) return ''
  try {
    return new Date(isoStr).toLocaleDateString('en-GB', {
      timeZone: 'Europe/London',
      day: 'numeric',
      month: 'short',
    })
  } catch {
    return isoStr
  }
}

// How many days between two YYYY-MM-DD strings
export function daysBetween(start, end) {
  return Math.round((new Date(end) - new Date(start)) / 86400000)
}
