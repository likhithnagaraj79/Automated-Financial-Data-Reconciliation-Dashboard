import { useState, useRef } from 'react'
import { DateRangePicker } from './components/DateRangePicker.jsx'
import { ForecastHorizonSlider } from './components/ForecastHorizonSlider.jsx'
import { WindChart } from './components/WindChart.jsx'
import { useWindData } from './hooks/useWindData.js'
import { daysAgo, todayStr } from './utils/dateUtils.js'
import './App.css'

const DEFAULT_HORIZON = 4

function App() {
  const [dateRange, setDateRange] = useState({
    start: daysAgo(30),
    end: todayStr(),
  })

  // horizon has two states: display value (updates on every tick)
  // and debounced value (triggers the API call after 500ms pause)
  const [horizon, setHorizon] = useState(DEFAULT_HORIZON)
  const [debouncedHorizon, setDebouncedHorizon] = useState(DEFAULT_HORIZON)
  const horizonTimerRef = useRef(null)

  function handleHorizonChange(val) {
    setHorizon(val)
    clearTimeout(horizonTimerRef.current)
    horizonTimerRef.current = setTimeout(() => setDebouncedHorizon(val), 500)
  }

  const { data, loading, error, refetch } = useWindData(
    dateRange.start,
    dateRange.end,
    debouncedHorizon
  )

  return (
    <div className="app">
      <header className="app-header">
        <div className="header-inner">
          <h1>Wind Forecast Monitor</h1>
          <p className="subtitle">GB wind generation — actual vs forecast (BMRS data)</p>
        </div>
      </header>

      <main className="app-main">
        {/* Controls */}
        <div className="controls-bar">
          <DateRangePicker
            start={dateRange.start}
            end={dateRange.end}
            onChange={setDateRange}
          />
          <ForecastHorizonSlider
            value={horizon}
            onChange={handleHorizonChange}
          />
        </div>

        {/* Error state */}
        {error && (
          <div className="error-banner">
            <span>{error}</span>
            <button className="retry-btn" onClick={refetch}>
              Retry
            </button>
          </div>
        )}

        {/* Chart */}
        <section className="chart-section">
          <WindChart
            data={data?.data}
            horizon={debouncedHorizon}
            loading={loading}
          />
        </section>

        {/* Summary stats — only show when data is loaded */}
        {data && !loading && (
          <div className="stats-bar">
            <span>
              <strong>{data.count.toLocaleString()}</strong> half-hour periods
            </span>
            <span>
              Forecast coverage:{' '}
              <strong>{data.forecast_coverage_pct}%</strong>
            </span>
            <span>
              Horizon: <strong>{debouncedHorizon}h</strong>
            </span>
            <span>
              {dateRange.start} → {dateRange.end}
            </span>
          </div>
        )}
      </main>
    </div>
  )
}

export default App
