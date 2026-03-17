// Date validation and manipulation — plain Date, no external deps

export const MIN_DATE = '2025-01-01' // earliest available BMRS WINDFOR data

export function isValidDateStr(str) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(str)) return false
  const d = new Date(str)
  return !isNaN(d.getTime())
}

// Returns an error object { error: string } or null if valid
export function validateQueryDates(start, end) {
  if (!start || !end) {
    return { error: 'start and end query params are required (YYYY-MM-DD)' }
  }
  if (!isValidDateStr(start) || !isValidDateStr(end)) {
    return { error: 'Dates must be in YYYY-MM-DD format' }
  }
  if (start < MIN_DATE) {
    return { error: `start cannot be before ${MIN_DATE} — that's when WINDFOR data begins` }
  }
  const todayStr = new Date().toISOString().slice(0, 10)
  if (end > todayStr) {
    return { error: 'end date cannot be in the future' }
  }
  if (start > end) {
    return { error: 'start must be on or before end' }
  }
  const diffDays = (new Date(end) - new Date(start)) / 86400000
  if (diffDays > 366) {
    return { error: 'Date range cannot exceed 1 year. Try a shorter range.' }
  }
  return null
}

export function validateHorizon(horizonStr) {
  if (horizonStr === undefined || horizonStr === null) {
    return { error: 'horizon query param is required (0–48)' }
  }
  const h = Number(horizonStr)
  if (isNaN(h) || h < 0 || h > 48) {
    return { error: 'horizon must be a number between 0 and 48' }
  }
  return null
}

// Subtract hours from an ISO datetime string, return ISO string
export function subtractHours(isoStr, hours) {
  return new Date(new Date(isoStr).getTime() - hours * 3600000).toISOString()
}

// Add hours to an ISO datetime string, return ISO string
export function addHours(isoStr, hours) {
  return new Date(new Date(isoStr).getTime() + hours * 3600000).toISOString()
}

// YYYY-MM-DD → '2025-01-15T00:00:00.000Z'
export function toStartOfDayUTC(dateStr) {
  return `${dateStr}T00:00:00.000Z`
}

// YYYY-MM-DD → '2025-01-15T23:59:59.999Z'
export function toEndOfDayUTC(dateStr) {
  return `${dateStr}T23:59:59.999Z`
}

// Get today's date as YYYY-MM-DD
export function todayStr() {
  return new Date().toISOString().slice(0, 10)
}

// Get yesterday's date as YYYY-MM-DD
export function yesterdayStr() {
  return new Date(Date.now() - 86400000).toISOString().slice(0, 10)
}
