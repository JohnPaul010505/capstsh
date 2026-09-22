from datetime import date
from typing import Any

from fastapi import APIRouter

from schemas import GoalAdjustRequest, GoalSuggestion
from services.gemini import goal_adjustments_ai
from services import db

router = APIRouter()


def _age_from_dob(dob: Any) -> Any:
    """Age computed from date_of_birth; profiles has no 'age' column."""
    if not dob:
        return None
    try:
        born = date.fromisoformat(str(dob)[:10])
        today = date.today()
        return today.year - born.year - ((today.month, today.day) < (born.month, born.day))
    except Exception:
        return None


def _pct(current: float, target: float) -> float:
    if target <= 0:
        return 0.0
    return max(0.0, min(100.0, current / target * 100.0))


@router.post("/goal-adjustments", response_model=list[GoalSuggestion])
async def get_goal_adjustments(req: GoalAdjustRequest):
    # The real table is "goals" (title/target_value/current_value/unit/status) -
    # the old code read a non-existent "fitness_goals" table and then crashed on
    # goal_type/progress_pct keys that the goals table does not have.
    try:
        goals = db.select("goals", "title, target_value, current_value, unit, status", member_id=req.member_id, order="created_at.desc", limit=10)  # type: ignore[assignment]
    except Exception:
        goals = []
    try:
        measurements = db.select("body_measurements", "weight_kg, body_fat_pct, measured_at", member_id=req.member_id, order="measured_at.desc", limit=10)  # type: ignore[assignment]
    except Exception:
        measurements = []
    profile: dict[str, Any] = {}
    try:
        p = db.select_single("profiles", "full_name, date_of_birth, gender", id=req.member_id)
        if p:
            profile = {
                "full_name": p.get("full_name", ""),
                "age": _age_from_dob(p.get("date_of_birth")),
                "gender": p.get("gender", ""),
            }
    except Exception:
        pass

    # Map to the keys services/gemini.py expects (goal_type, progress_pct).
    goals_for_ai = []
    for g in goals:
        c = float(g.get("current_value", 0) or 0)
        t = float(g.get("target_value", 0) or 0)
        goals_for_ai.append({
            "goal_type": (g.get("title") or "general")[:60],
            "current_value": c,
            "target_value": t,
            "progress_pct": round(_pct(c, t), 1),
            "unit": g.get("unit", ""),
            "status": g.get("status", ""),
        })
    meas_for_ai = [
        {
            "measurement_date": m.get("measured_at", ""),
            "weight": m.get("weight_kg"),
            "body_fat": m.get("body_fat_pct"),
        }
        for m in measurements
    ]

    ai_result = goal_adjustments_ai(goals_for_ai, meas_for_ai, profile)
    if ai_result and isinstance(ai_result, list):
        return [GoalSuggestion(**r) for r in ai_result[:3]]

    # Deterministic fallback on the real goals columns (no KeyError possible).
    suggestions = []
    for g in goals:
        title = (g.get("title") or "general")[:60]
        c = float(g.get("current_value", 0) or 0)
        t = float(g.get("target_value", 0) or 0)
        pct = _pct(c, t)
        if pct >= 100:
            suggestions.append(GoalSuggestion(
                goal_type=title, current_value=c, suggested_value=round(t * 1.15, 2),
                reason="Goal achieved! Consider increasing the target by 15% for continued progress."
            ))
        elif pct < 20:
            suggestions.append(GoalSuggestion(
                goal_type=title, current_value=c, suggested_value=round(max(t * 0.8, c + 1), 2),
                reason="Low progress — consider a smaller interim target to build momentum."
            ))
    if not suggestions:
        suggestions.append(GoalSuggestion(
            goal_type="general", current_value=0, suggested_value=0,
            reason="Not enough data for goal adjustment suggestions. Log more workouts and meals."
        ))
    return suggestions[:3]
