export const HEALTH_BACKGROUND_QUESTIONS = [
  { key: 'illnessOrHeartProblem', label: 'Have you had any illness or heart problem?' },
  { key: 'recentDoctorVisit', label: 'Have you seen a doctor in the last two years for any health problem?' },
  { key: 'movementDifficulty', label: 'Do you have difficulty standing, bending, lifting, or doing other movements?' },
  { key: 'jointBackShoulderLegInjury', label: 'Have you had problems with your joints, back, shoulders, legs, or an injury?' },
] as const

export type HealthBackgroundKey = (typeof HEALTH_BACKGROUND_QUESTIONS)[number]['key']
export type HealthBackgroundAnswers = Record<HealthBackgroundKey, { choice: string; details: string }>

export const emptyHealthBackground: HealthBackgroundAnswers = Object.fromEntries(
  HEALTH_BACKGROUND_QUESTIONS.map(({ key }) => [key, { choice: '', details: '' }]),
) as HealthBackgroundAnswers

interface Props {
  value: HealthBackgroundAnswers
  onChange: (value: HealthBackgroundAnswers) => void
  readOnly?: boolean
}

export default function HealthBackgroundSection({ value, onChange, readOnly = false }: Props) {
  const setChoice = (key: HealthBackgroundKey, choice: string) => {
    onChange({
      ...value,
      [key]: { choice, details: choice === 'other' ? value[key]?.details ?? '' : '' },
    })
  }

  return (
    <section className="border-t border-line pt-4 mt-4">
      <h3 className="text-sm font-semibold text-fg-strong mb-1">Health Background Screening</h3>
      <p className="text-xs text-fg-muted mb-3">Applicant responses. Keep this information limited to authorized administrators.</p>
      <div className="space-y-3">
        {HEALTH_BACKGROUND_QUESTIONS.map(({ key, label }, index) => {
          const answer = value[key] ?? { choice: '', details: '' }
          return (
            <fieldset key={key} className="rounded-xl border border-line bg-overlay-4 p-3">
              <legend className="px-1 text-xs font-medium text-fg-strong">{index + 1}. {label}</legend>
              <div className="flex flex-wrap gap-x-4 gap-y-2 text-xs text-fg">
                {[
                  ['yes', 'Yes, I have.'],
                  ['no', "No, I don't have."],
                  ['other', 'Other'],
                ].map(([choice, caption]) => (
                  <label key={choice} className="inline-flex items-center gap-1.5">
                    <input
                      type="radio"
                      name={`health-${key}`}
                      value={choice}
                      checked={answer.choice === choice}
                      disabled={readOnly}
                      onChange={() => setChoice(key, choice)}
                    />
                    {caption}
                  </label>
                ))}
              </div>
              {answer.choice === 'other' && (
                <textarea
                  value={answer.details}
                  maxLength={500}
                  rows={2}
                  readOnly={readOnly}
                  aria-label={`Details for ${label}`}
                  onChange={event => onChange({
                    ...value,
                    [key]: { ...answer, details: event.target.value },
                  })}
                  className="mt-3 w-full rounded-lg border border-line bg-page-deep px-3 py-2 text-sm text-fg-strong focus:outline-none focus:border-[#7C3AED]"
                  placeholder="Please explain"
                />
              )}
              {!answer.choice && <p className="mt-2 text-xs text-fg-faint">No response recorded.</p>}
            </fieldset>
          )
        })}
      </div>
    </section>
  )
}
