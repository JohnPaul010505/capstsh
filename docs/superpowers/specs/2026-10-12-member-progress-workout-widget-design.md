# Member Forecast, Workout Timing, and Goal Widget Design

**Status:** Design approved in chat; awaiting written-spec review before implementation.

## Goal

Make the member home forecast easy to understand and grounded in that member's recorded weight history; show active and break time separately after a workout and in calendar history while excluding breaks from calorie estimates; and improve the goal home-screen button and Android widget sizing.

## Member forecast

- Use only the signed-in member's `body_measurements` weight entries, ordered by measurement date.
- Keep the existing 30-day personal trend calculation and its minimum-history/plausibility guardrails; do not mix goal pace, target weight, attendance, or other members' data into the personal weight estimate.
- Simplify the card to a concise label and one value line: current logged weight → estimated weight in 30 days. Keep confidence out of this compact member card.
- If the member has no usable trend yet, show the latest recorded weight (if available) and one short instruction to log more weigh-ins. Never present goal math as a personal forecast.

## Workout time and calories

- Retain the session's existing active and rest counters.
- Calculate exercise calories from active seconds only: `MET × member weight kg × active seconds / 3600`. Paused/break seconds contribute zero kcal.
- In the completion summary, show active time and break time as separate values alongside total session duration and active-only kcal.
- Persist per-exercise active and break seconds to `workout_logs`, because calendar history groups those exercise rows into sessions. Add nullable columns so existing records remain readable. For older rows without these values, continue showing their stored duration and calories without inventing an active/rest split.
- Load and sum the new fields in the calendar session header; preserve existing exercise details and proof links.

## Goal shortcut and Android widget

- Make the “Add to Home Screen” action white, full width within the goal card, and an accessible touch target with clear loading/confirmation feedback.
- Keep the widget's existing dark visual theme. Make its native layout adapt to the launcher-provided width/height and remain resizable. Use compact and expanded arrangements where appropriate so resizing does not clip title, values, or progress ring.
- Keep the existing widget data fields, refresh triggers, and deep link to Goals.

## Files and data surfaces expected

- Flutter member home forecast card and its existing prediction service contract.
- Workout session state/calorie calculation, completion summary, and calendar workout query/session rendering.
- A new additive Supabase migration for nullable `active_seconds` and `rest_seconds` columns, plus the Flutter insert/select changes that use them.
- Goal card button styling and Android widget XML/provider sizing behavior.

## Compatibility and failure behavior

- Members with sparse weight history see the existing insufficient-history state in simpler language.
- Existing workout rows remain valid with null active/rest values.
- If the launcher does not support pinning directly, retain the manual launcher widget instructions.
- Do not change administrator predictions, trainer screens, other member screens, unrelated database schemas, or external hosting settings.

## Review checklist

- Forecast values are derived only from the selected member's actual weigh-ins and remain explicitly estimates.
- Forecast card no longer shows goal pace or redundant explanatory paragraphs.
- Break time appears separately in completion and calendar history.
- Calories in the completion summary and newly written workout rows exclude rest time.
- Historical rows without timing columns continue to render.
- The shortcut is white and fills the goal card's available width.
- Widget responds to launcher resizing without clipping important content.
- Flutter analysis/build and admin-independent migration review complete; no unrelated files are changed.
