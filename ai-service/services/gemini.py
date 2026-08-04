import os
import json
from typing import Optional

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_ENABLED = bool(GEMINI_API_KEY)

if GEMINI_ENABLED:
    import google.generativeai as genai
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel("gemini-1.5-flash")

def food_recommendations_ai(meal_type: str, recent_logs: list[dict], profile: dict) -> Optional[list[dict]]:
    if not GEMINI_ENABLED:
        return None
    try:
        logs_text = "; ".join(
            f"{l.get('meal_type','')}: {l.get('food_name','')} ({l.get('calories',0)} cal)"
            for l in recent_logs[-10:]
        )
        prompt = f"""You are a fitness nutritionist. Member: {profile.get('full_name','')}, 
age {profile.get('age','unknown')}, goal {profile.get('fitness_goal','general')}.
Recent meals: {logs_text or 'none'}.
Suggest 3 healthier {meal_type or 'meal'} options. Return JSON array with: 
food_name, portion, calories, protein_g, carbs_g, fat_g, reason.
Keep it realistic and specific. Return ONLY valid JSON, no markdown."""
        resp = model.generate_content(prompt)
        text = resp.text.strip().removeprefix("```json").removesuffix("```").strip()
        return json.loads(text)
    except Exception as e:
        print(f"Gemini food error: {e}")
        return None

def goal_adjustments_ai(goals: list[dict], measurements: list[dict], profile: dict) -> Optional[list[dict]]:
    if not GEMINI_ENABLED:
        return None
    try:
        goals_text = "; ".join(f"{g.get('goal_type','')}: current={g.get('current_value')}, target={g.get('target_value')}, progress={g.get('progress_pct',0)}%" for g in goals)
        meas_text = "; ".join(f"{m.get('measurement_date','')}: weight={m.get('weight')}, bf={m.get('body_fat')}" for m in measurements[-5:])
        prompt = f"""Member: {profile.get('full_name','')}, age {profile.get('age','unknown')}.
Goals: {goals_text or 'none'}.
Recent measurements: {meas_text or 'none'}.
Suggest 3 goal adjustments. Return JSON array with: goal_type, current_value, suggested_value, reason.
Return ONLY valid JSON, no markdown."""
        resp = model.generate_content(prompt)
        text = resp.text.strip().removeprefix("```json").removesuffix("```").strip()
        return json.loads(text)
    except Exception as e:
        print(f"Gemini goal error: {e}")
        return None
