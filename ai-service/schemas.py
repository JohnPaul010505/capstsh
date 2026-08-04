from pydantic import BaseModel
from typing import Optional

class MemberIdentifier(BaseModel):
    member_id: str
    meal_type: Optional[str] = None

class GoalAdjustRequest(BaseModel):
    member_id: str

class PredictionRequest(BaseModel):
    member_id: str
    days_ahead: int = 30

class FoodRecommendation(BaseModel):
    food_name: str
    portion: str
    calories: int
    protein_g: int
    carbs_g: int
    fat_g: int
    reason: str

class GoalSuggestion(BaseModel):
    goal_type: str
    current_value: float
    suggested_value: float
    reason: str

class PredictionResult(BaseModel):
    prediction_type: str
    current_value: float
    predicted_value: float
    unit: str
    days_ahead: int
    confidence: float
