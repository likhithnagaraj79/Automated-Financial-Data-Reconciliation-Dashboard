import {
  ComposedChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts'
import { formatDateTime, formatDateTick, daysBetween } from '../utils/dateUtils.js'

function CustomTooltip({ active, payload, label }) {
  if (!active || !payload?.length) return null

  return (
    <div className="chart-tooltip">
      <p className="tooltip-time">{formatDateTime(label)}</p>
      {payload.map((p) => (
        <p key={p.name} className="tooltip-value" style={{ color: p.color }}>
          {p.name}:{' '}
          {p.value != null ? `${Math.round(p.value).toLocaleString()} MW` : 'No data'}
        </p>
      ))}
    </div>
  )
}

// Thin out very dense datasets so the chart stays responsive
// (recharts handles 2k points fine; over 5k it gets slow)
function downsample(data, maxPoints = 2000) {
  if (data.length <= maxPoints) return data
  const step = Math.ceil(data.length / maxPoints)
  return data.filter((_, i) => i % step === 0)
}

export function WindChart({ data, horizon, loading }) {
  if (loading) {
    return (
      <div className="chart-placeholder-box">
        <div className="loading-spinner" />
        <p>Fetching wind data — this may take a moment on first load…</p>
      </div>
    )
  }

  if (!data || data.length === 0) {
    return (
      <div className="chart-placeholder-box chart-empty">
        <p>No data for this range.</p>
        <p className="empty-hint">Try a different date range or check that data is available from Jan 2025.</p>
      </div>
    )
  }

  const chartData = downsample(data)
  const totalPoints = data.length
  const forecastCount = data.filter((d) => d.has_forecast).length
  const coveragePct = Math.round((forecastCount / totalPoints) * 100)

  // how many ticks to show on x-axis — avoid a wall of dates
  const tickInterval = Math.max(1, Math.floor(chartData.length / 24))

  return (
    <div className="chart-wrapper">
      {coveragePct < 80 && (
        <div className="coverage-warning">
          Forecast coverage is {coveragePct}% — fewer than 80% of half-hours have a
          forecast at <strong>{horizon}h</strong> horizon. Try a smaller horizon.
        </div>
      )}

      {chartData.length < data.length && (
        <p className="downsample-note">
          Showing {chartData.length.toLocaleString()} of{' '}
          {totalPoints.toLocaleString()} data points for performance.
        </p>
      )}

      <ResponsiveContainer width="100%" height={420}>
        <ComposedChart
          data={chartData}
          margin={{ top: 10, right: 16, left: 0, bottom: 10 }}
        >
          <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
          <XAxis
            dataKey="start_time"
            tickFormatter={formatDateTick}
            interval={tickInterval}
            tick={{ fontSize: 11, fill: '#64748b' }}
            tickLine={false}
          />
          <YAxis
            tick={{ fontSize: 11, fill: '#64748b' }}
            tickLine={false}
            axisLine={false}
            width={65}
            tickFormatter={(v) => `${(v / 1000).toFixed(1)}GW`}
          />
          <Tooltip content={<CustomTooltip />} />
          <Legend
            wrapperStyle={{ fontSize: '13px', paddingTop: '8px' }}
          />
          <Line
            type="monotone"
            dataKey="actual_generation"
            name="Actual"
            stroke="#2563eb"
            dot={false}
            strokeWidth={1.5}
            connectNulls={false}
          />
          <Line
            type="monotone"
            dataKey="forecast_generation"
            name={`Forecast (${horizon}h ahead)`}
            stroke="#f59e0b"
            dot={false}
            strokeWidth={1.5}
            strokeDasharray="5 3"
            connectNulls={false}
          />
        </ComposedChart>
      </ResponsiveContainer>
    </div>
  )
}
