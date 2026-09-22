from datetime import date

from fastapi import APIRouter

from schemas import MemberIdentifier, FoodRecommendation
from services.gemini import food_recommendations_ai
from services import db
from typing import Any

router = APIRouter()

# Filipino fallbacks aligned with the nutrition_foods seed (DOST-FNRI PhilFCT).
# Macros are estimates for one serving including rice/sides where noted.
FALLBACKS: dict[str, list[dict[str, Any]]] = {
    "breakfast": [
        {"food_name": "Tapsilog (Beef Tapa + Sinangag + Egg)", "portion": "1 plate (300g)", "calories": 450, "protein_g": 28, "carbs_g": 45, "fat_g": 16, "reason": "High-protein Filipino breakfast for steady morning energy"},
        {"food_name": "Champorado with Dilis", "portion": "1 bowl (300g)", "calories": 320, "protein_g": 12, "carbs_g": 58, "fat_g": 6, "reason": "Carb-forward but balanced by the salty dilis protein"},
        {"food_name": "Pandesal with Kesong Puti", "portion": "3 pcs (150g)", "calories": 300, "protein_g": 14, "carbs_g": 40, "fat_g": 9, "reason": "Light, classic start that keeps calories in check"},
    ],
    "lunch": [
        {"food_name": "Chicken Adobo with Rice", "portion": "1 cup viand + 1 cup rice", "calories": 520, "protein_g": 28, "carbs_g": 60, "fat_g": 16, "reason": "Balanced macros with the classic Filipino flavor"},
        {"food_name": "Sinigang na Baboy with Rice", "portion": "1 bowl + 1 cup rice", "calories": 460, "protein_g": 20, "carbs_g": 58, "fat_g": 10, "reason": "Vegetable-rich sour soup keeps it light"},
        {"food_name": "Pinakbet with Grilled Bangus", "portion": "1 plate (350g)", "calories": 430, "protein_g": 26, "carbs_g": 32, "fat_g": 18, "reason": "High protein and fiber from mixed vegetables"},
    ],
    "dinner": [
        {"food_name": "Tinola with Rice", "portion": "1 bowl + 1 cup rice", "calories": 420, "protein_g": 18, "carbs_g": 56, "fat_g": 9, "reason": "Light dinner with a ginger-rich broth"},
        {"food_name": "Ginisang Monggo with Malunggay", "portion": "1 bowl (300g)", "calories": 380, "protein_g": 18, "carbs_g": 50, "fat_g": 10, "reason": "Plant protein and fiber for the evening"},
        {"food_name": "Grilled Bangus with Ensaladang Talong", "portion": "1 fillet + side", "calories": 400, "protein_g": 26, "carbs_g": 18, "fat_g": 22, "reason": "Omega-3 rich fish with a fresh vegetable side"},
    ],
    "snack": [
        {"food_name": "Boiled Saba Banana", "portion": "2 pcs (150g)", "calories": 200, "protein_g": 3, "carbs_g": 50, "fat_g": 1, "reason": "Quick pre- or post-workout carbohydrates"},
        {"food_name": "Puto with Cheese", "portion": "2 pcs (120g)", "calories": 240, "protein_g": 6, "carbs_g": 42, "fat_g": 5, "reason": "Light snack that refills glycogen between sessions"},
        {"food_name": "Fresh Buko Juice", "portion": "1 glass (250ml)", "calories": 120, "protein_g": 1, "carbs_g": 28, "fat_g": 1, "reason": "Natural electrolytes for hydration"},
    ],
}


def _age_from_dob(dob: Any) -> Any:
    """Age computed from date_of_birth; None when unknown. profiles has no
    'age' column (that query used to 400 and silently drop all context)."""
    if not dob:
        return None
    try:
        born = date.fromisoformat(str(dob)[:10])
        today = date.today()
        return today.year - born.year - ((today.month, today.day) < (born.month, born.day))
    except Exception:
        return None


def _member_context(member_id: str) -> dict[str, Any]:
    """Profile context for the Gemini prompt, built only from real columns:
    profiles(full_name, date_of_birth, gender) + goals(title, status)."""
    profile: dict[str, Any] = {}
    try:
        p = db.select_single("profiles", "full_name, date_of_birth, gender", id=member_id) or {}
        profile["full_name"] = p.get("full_name", "")
        profile["age"] = _age_from_dob(p.get("date_of_birth"))
        profile["gender"] = p.get("gender", "")
    except Exception:
        pass
    try:
        goals = db.select("goals", "title, status", member_id=member_id, order="created_at.desc", limit=5)  # type: ignore[assignment]
        active = [g.get("title", "") for g in goals if g.get("status") == "active" and g.get("title")]
        if active:
            profile["fitness_goal"] = ", ".join(active)
    except Exception:
        pass
    return profile


@router.post("/food-recommendations", response_model=list[FoodRecommendation])
async def get_food_recommendations(req: MemberIdentifier):
    meal_type = (req.meal_type or "lunch").lower()
    try:
        # meal_logs timestamps live in meal_time (logged_at does not exist here).
        logs = db.select("meal_logs", "meal_type, food_name, calories, meal_time", member_id=req.member_id, order="meal_time.desc", limit=20)  # type: ignore[assignment]
    except Exception:
        logs = []
    profile = _member_context(req.member_id)
    result = food_recommendations_ai(meal_type, logs, profile)
    if result and isinstance(result, list):
        return [FoodRecommendation(**r) for r in result[:5]]
    fallback = FALLBACKS.get(meal_type, FALLBACKS["lunch"])
    return [FoodRecommendation(**r) for r in fallback]