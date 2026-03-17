import { getDb } from '../utils/db.js'

// Bulk upsert — ON CONFLICT(start_time, publish_time) ignores duplicate entries
export function upsertForecasts(records) {
  if (!records || records.length === 0) return 0

  const db = getDb()
  const stmt = db.prepare(`
    INSERT INTO forecasts (start_time, publish_time, generation)
    VALUES (?, ?, ?)
    ON CONFLICT(start_time, publish_time) DO UPDATE SET
      generation = excluded.generation
  `)

  db.exec('BEGIN')
  try {
    for (const r of records) {
      stmt.run(r.start_time, r.publish_time, r.generation)
    }
    db.exec('COMMIT')
  } catch (e) {
    db.exec('ROLLBACK')
    throw e
  }

  return records.length
}

// All forecasts where startTime falls within the range
export function getForecastsForRange(startISO, endISO) {
  const db = getDb()
  return db.prepare(`
    SELECT start_time, publish_time, generation
    FROM forecasts
    WHERE start_time >= ? AND start_time <= ?
    ORDER BY start_time ASC, publish_time ASC
  `).all(startISO, endISO)
}

export function countForecastsInRange(startISO, endISO) {
  const db = getDb()
  const row = db.prepare(`
    SELECT COUNT(*) as count
    FROM forecasts
    WHERE start_time >= ? AND start_time <= ?
  `).get(startISO, endISO)
  return row?.count ?? 0
}
