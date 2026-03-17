export function ForecastHorizonSlider({ value, onChange }) {
  return (
    <div className="horizon-slider">
      <p className="control-label">
        Forecast horizon: <strong>{value}h ahead</strong>
      </p>
      <div className="slider-row">
        <span className="slider-tick">0h</span>
        <input
          type="range"
          min={0}
          max={48}
          step={1}
          value={value}
          onChange={(e) => onChange(Number(e.target.value))}
          className="range-input"
          aria-label="Forecast horizon in hours"
        />
        <span className="slider-tick">48h</span>
      </div>
      <p className="horizon-hint">
        Each data point shows the forecast that was published at least{' '}
        <strong>{value}h</strong> before that half-hour window
      </p>
    </div>
  )
}
