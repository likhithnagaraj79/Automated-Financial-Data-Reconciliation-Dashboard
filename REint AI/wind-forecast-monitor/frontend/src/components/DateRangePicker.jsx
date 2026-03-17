import { useState } from 'react'
import { MIN_DATE, todayStr, daysAgo } from '../utils/dateUtils.js'

const PRESETS = [
  { label: '7 days', getDates: () => ({ start: daysAgo(7), end: todayStr() }) },
  { label: '30 days', getDates: () => ({ start: daysAgo(30), end: todayStr() }) },
  { label: '90 days', getDates: () => ({ start: daysAgo(90), end: todayStr() }) },
]

export function DateRangePicker({ start, end, onChange }) {
  const [validationMsg, setValidationMsg] = useState('')

  function handleStartChange(e) {
    const val = e.target.value
    if (val > end) {
      setValidationMsg('Start date must be on or before end date')
      return
    }
    setValidationMsg('')
    onChange({ start: val, end })
  }

  function handleEndChange(e) {
    const val = e.target.value
    if (val < start) {
      setValidationMsg('End date must be on or after start date')
      return
    }
    setValidationMsg('')
    onChange({ start, end: val })
  }

  function applyPreset(preset) {
    setValidationMsg('')
    onChange(preset.getDates())
  }

  return (
    <div className="date-range-picker">
      <p className="control-label">Date range</p>
      <div className="date-inputs">
        <label className="date-field">
          <span>From</span>
          <input
            type="date"
            value={start}
            min={MIN_DATE}
            max={end || todayStr()}
            onChange={handleStartChange}
          />
        </label>
        <span className="date-sep">→</span>
        <label className="date-field">
          <span>To</span>
          <input
            type="date"
            value={end}
            min={start || MIN_DATE}
            max={todayStr()}
            onChange={handleEndChange}
          />
        </label>
      </div>

      {validationMsg && <p className="validation-msg">{validationMsg}</p>}

      <div className="preset-buttons">
        {PRESETS.map((p) => (
          <button
            key={p.label}
            className="preset-btn"
            onClick={() => applyPreset(p)}
          >
            {p.label}
          </button>
        ))}
      </div>
    </div>
  )
}
