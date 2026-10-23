import { useState, type KeyboardEvent } from 'react'

const blockNonDigit = (event: KeyboardEvent<HTMLInputElement>) => {
  if (['e', 'E', '+', '-', '.'].includes(event.key)) event.preventDefault()
}

export default function TimeSelect({ value, label, onChange }: { value: string; label: string; onChange: (value: string) => void }) {
  const [hour = '09', minute = '00'] = value.split(':')
  const hour24 = Number(hour)
  const period = hour24 < 12 ? 'AM' : 'PM'
  const hour12 = hour24 % 12 || 12
  const [hourInput, setHourInput] = useState(String(hour12))
  const [minuteInput, setMinuteInput] = useState(minute)
  const update = (nextHour: number, nextMinute: number, nextPeriod: string) => {
    const next24 = nextHour % 12 + (nextPeriod === 'PM' ? 12 : 0)
    onChange(`${String(next24).padStart(2, '0')}:${String(nextMinute).padStart(2, '0')}`)
  }
  const inputClass = 'min-w-0 rounded-lg border border-line bg-overlay-8 px-1.5 py-2 text-sm text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50'
  return (
    <fieldset className="min-w-0 flex-1">
      <legend className="mb-1 text-xs text-fg-muted">{label}</legend>
      <div className="flex gap-1">
        <input aria-label={`${label} hour`} type="number" inputMode="numeric" min="1" max="12" step="1" className={`${inputClass} w-12`} value={hourInput}
          onKeyDown={blockNonDigit}
          onChange={e => { const next = e.target.value; if (next.length > 2 || (next && (!/^\d{1,2}$/.test(next) || Number(next) > 12))) return; setHourInput(next); const parsed = Number(next); if (next && parsed >= 1) update(parsed, Number(minute), period) }}
          onBlur={() => setHourInput(String(hour12))} />
        <input aria-label={`${label} minute`} type="number" inputMode="numeric" min="0" max="59" step="1" className={`${inputClass} w-14`} value={minuteInput}
          onKeyDown={blockNonDigit}
          onChange={e => { const next = e.target.value; if (next.length > 2 || (next && (!/^\d{1,2}$/.test(next) || Number(next) > 59))) return; setMinuteInput(next); if (next) update(hour12, Number(next), period) }}
          onBlur={() => setMinuteInput(String(Number(minute)).padStart(2, '0'))} />
        <select aria-label={`${label} AM or PM`} className={`${inputClass} w-16`} value={period} onChange={e => update(hour12, Number(minute), e.target.value)}><option>AM</option><option>PM</option></select>
      </div>
    </fieldset>
  )
}
