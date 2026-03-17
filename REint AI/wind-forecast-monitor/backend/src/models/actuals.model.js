import { getDb } from '../utils/db.js'

// Bulk upsert — ON CONFLICT updates generation if it changes
export function upsertActuals(records) {
  if (!records || records.length === 0) return 0

  const db = getDb()
  const stmt = db.prepare(`
    INSERT INTO actuals (start_time, settlement_date, settlement_period, generation, fuel_type)
    VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(start_time) DO UPDATE SET
      generation = excluded.generation,
      settlement_date = excluded.settlement_date,
      settlement_period = excluded.settlement_period
  `)

  db.exec('BEGIN')
  try {
    for (const r of records) {
      stmt.run(
        r.start_time,
        r.settlement_date ?? null,
        r.settlement_period ?? null,
        r.generation,
        r.fuel_type ?? 'WIND'
      )
    }
    db.exec('COMMIT')
  } catch (e) {
    db.exec('ROLLBACK')
    throw e
  }

  return records.length
}

export function getActualsByDateRange(startISO, endISO) {
  const db = getDb()
  return db.prepare(`
    SELECT start_time, generation, settlement_date, settlement_period
    FROM actuals
    WHERE start_time >= ? AND start_time <= ?
    ORDER BY start_time ASC
  `).all(startISO, endISO)
}

export function countActualsInRange(startISO, endISO) {
  const db = getDb()
  const row = db.prepare(`
    SELECT COUNT(*) as count
    FROM actuals
    WHERE start_time >= ? AND start_time <= ?
  `).get(startISO, endISO)
  return row?.count ?? 0
}
