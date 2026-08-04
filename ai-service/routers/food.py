from fastapi import APIRouter
from schemas import MemberIdentifier, FoodRecommendation
from services.gemini import food_recommendations_ai
from services import db
from datetime import date

router = APIRouter()

FALLBACKS: dict[str, list[dict]] = {
    "breakfast": [
        {"food_name": "Oatmeal with Berries", "portion": "1 bowl (200g)", "calories": 280, "protein_g": 10, "carbs_g": 45, "fat_g": 6, "reason": "High fiber, slow-release energy"},
        {"food_name": "Greek Yogurt Parfait", "portion": "1 cup (250g)", "calories": 220, "protein_g": 20, "carbs_g": 25, "fat_g": 5, "reason": "Rich in protein and probiotics"},
        {"food_name": "Egg White Omelette", "portion": "3 eggs + veggies", "calories": 180, "protein_g": 24, "carbs_g": 5, "fat_g": 4, "reason": "Lean protein source"},
    ],
    "lunch": [
        {"food_name": "Grilled Chicken Salad", "portion": "1 plate (300g)", "calories": 350, "protein_g": 35, "carbs_g": 15, "fat_g": 12, "reason": "Balanced macros, nutrient-dense"},
        {"food_name": "Quinoa Buddha Bowl", "portion": "1 bowl (350g)", "calories": 380, "protein_g": 15, "carbs_g": 50, "fat_g": 14, "reason": "Complete protein + complex carbs"},
        {"food_name": "Turkey Wrap", "portion": "1 wrap (250g)", "calories": 320, "protein_g": 28, "carbs_g": 30, "fat_g": 10, "reason": "Portable, lean protein"},
    ],
    "dinner": [
        {"food_name": "Baked Salmon with Asparagus", "portion": "1 fillet + sides", "calories": 420, "protein_g": 38, "carbs_g": 12, "fat_g": 22, "reason": "Omega-3 rich, muscle recovery"},
        {"food_name": "Lean Steak with Sweet Potato", "portion": "200g steak + 1 potato", "calories": 450, "protein_g": 42, "carbs_g": 35, "fat_g": 14, "reason": "Iron-rich, sustained energy"},
        {"food_name": "Stir-fried Tofu with Vegetables", "portion": "1 plate (300g)", "calories": 310, "protein_g": 22, "carbs_g": 25, "fat_g": 14, "reason": "Plant-based, high protein"},
    ],
    "snack": [
        {"food_name": "Protein Shake", "portion": "1 scoop (30g)", "calories": 120, "protein_g": 25, "carbs_g": 3, "fat_g": 2, "reason": "Quick post-workout recovery"},
        {"food_name": "Apple with Almond Butter", "portion": "1 apple + 1 tbsp", "calories": 200, "protein_g": 5, "carbs_g": 28, "fat_g": 10, "reason": "Healthy fats + natural sugars"},
        {"food_name": "Cottage Cheese with Pineapple", "portion": "1 cup (200g)", "calories": 180, "protein_g": 22, "carbs_g": 14, "fat_g": 5, "reason": "Casein protein, satiating"},
    ],
}

@router.post("/food-recommendations", response_model=list[FoodRecommendation])
async def get_food_recommendations(req: MemberIdentifier):
    meal_type = (req.meal_type or "lunch").lower()
    try:
        logs = db.select("meal_logs", "*", member_id=req.member_id, order="logged_at.desc", limit=20)
    except Exception:
        logs = []
    try:
        profile = db.select_single("profiles", "full_name, age, fitness_goal", id=req.member_id) or {}
    except Exception:
        profile = {}
    result = food_recommendations_ai(meal_type, logs, profile)
    if result and isinstance(result, list):
        return [FoodRecommendation(**r) for r in result[:5]]
    fallback = FALLBACKS.get(meal_type, FALLBACKS["lunch"])
    return [FoodRecommendation(**r) for r in fallback]
