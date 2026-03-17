import { useState } from 'react'
import './App.css'

// TODO: import components once built in Phase 3
// import DateRangePicker from './components/DateRangePicker'
// import ForecastHorizonSlider from './components/ForecastHorizonSlider'
// import WindChart from './components/WindChart'

function App() {
  const [dateRange, setDateRange] = useState({
    start: null,
    end: null,
  })
  const [horizon, setHorizon] = useState(4) // default to 4-hour horizon

  return (
    <div className="app">
      <header className="app-header">
        <h1>Wind Forecast Monitor</h1>
        <p className="subtitle">GB wind generation — actual vs forecast</p>
      </header>

      <main className="app-main">
        {/* Controls will go here */}
        <div className="controls-placeholder">
          <p>Date picker + horizon slider coming in Phase 3</p>
          <p>Current horizon: {horizon}h</p>
        </div>

        {/* Chart will go here */}
        <div className="chart-placeholder">
          <p>Chart component coming in Phase 3</p>
        </div>
      </main>
    </div>
  )
}

export default App
