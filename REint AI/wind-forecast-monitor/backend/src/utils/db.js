// Using Node.js built-in SQLite (node:sqlite) — available in Node 22+
// No npm package needed, no native compilation issues
import { DatabaseSync } from 'node:sqlite'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'
import { mkdirSync } from 'fs'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

const DB_PATH = process.env.DB_PATH
  ? join(process.cwd(), process.env.DB_PATH)
  : join(__dirname, '../../data/wind_monitor.db')

let db

export function getDb() {
  if (!db) {
    // make sure the data/ directory exists before opening
    mkdirSync(dirname(DB_PATH), { recursive: true })
    db = new DatabaseSync(DB_PATH)

    // WAL mode gives much better concurrent read performance
    db.exec('PRAGMA journal_mode = WAL')
    db.exec('PRAGMA foreign_keys = ON')
  }
  return db
}

export function initDb() {
  const database = getDb()

  database.exec(`
    CREATE TABLE IF NOT EXISTS actuals (
      id                INTEGER PRIMARY KEY AUTOINCREMENT,
      start_time        TEXT    UNIQUE NOT NULL,
      settlement_date   TEXT,
      settlement_period INTEGER,
      generation        REAL    NOT NULL,
      fuel_type         TEXT    DEFAULT 'WIND',
      created_at        TEXT    DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_actuals_start_time
      ON actuals(start_time);

    CREATE TABLE IF NOT EXISTS forecasts (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      start_time   TEXT NOT NULL,
      publish_time TEXT NOT NULL,
      generation   REAL NOT NULL,
      created_at   TEXT DEFAULT (datetime('now')),
      UNIQUE(start_time, publish_time)
    );

    CREATE INDEX IF NOT EXISTS idx_forecasts_start_publish
      ON forecasts(start_time, publish_time);
  `)

  console.log('Database ready at:', DB_PATH)
  return database
}
