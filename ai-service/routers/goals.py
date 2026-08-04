from fastapi import APIRouter
from schemas import GoalAdjustRequest, GoalSuggestion
from services.gemini import goal_adjustments_ai
from services import db

router = APIRouter()

@router.post("/goal-adjustments", response_model=list[GoalSuggestion])
async def get_goal_adjustments(req: GoalAdjustRequest):
    try:
        goals = db.select("fitness_goals", "*", member_id=req.member_id)
    except Exception:
        goals = []
    try:
        measurements = db.select("body_measurements", "*", member_id=req.member_id, order="measured_at.desc", limit=10)
    except Exception:
        measurements = []
    profile = {}
    try:
        p = db.select_single("profiles", "full_name, age", id=req.member_id)
        if p: profile = p
    except Exception:
        pass
    ai_result = goal_adjustments_ai(goals, measurements, profile)
    if ai_result and isinstance(ai_result, list):
        return [GoalSuggestion(**r) for r in ai_result[:3]]
    suggestions = []
    for g in goals:
        c = g.get("current_value", 0) or 0
        t = g.get("target_value", 0) or 0
        pct = g.get("progress_pct", 0) or 0
        if pct >= 100:
            suggestions.append(GoalSuggestion(
                goal_type=g["goal_type"], current_value=c, suggested_value=t * 1.15,
                reason="Goal achieved! Consider increasing target by 15% for continued progress."
            ))
        elif pct < 20:
            suggestions.append(GoalSuggestion(
                goal_type=g["goal_type"], current_value=c, suggested_value=max(t * 0.8, c + 1),
                reason="Low progress — consider a smaller interim target to build momentum."
            ))
    if not suggestions:
        suggestions.append(GoalSuggestion(
            goal_type="general", current_value=0, suggested_value=0,
            reason="Not enough data for goal adjustment suggestions. Log more workouts and meals."
        ))
    return suggestions[:3]
