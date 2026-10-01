from pydantic import BaseModel
from typing import Optional

class PredictionRequest(BaseModel):
    member_id: str
    days_ahead: int = 30

class PredictionResult(BaseModel):
    prediction_type: str
    current_value: float
    predicted_value: float
    unit: str
    days_ahead: int
    confidence: float
    # --- Explainability (all optional: older rows and the mobile client that
    # --- only reads the six fields above stay valid).
    data_points: Optional[int] = None      # measurements / weeks of history used
    span_days: Optional[int] = None        # how far apart that history is
    date_from: Optional[str] = None        # first reading the fit used
    date_to: Optional[str] = None          # latest reading the fit used
    daily_rate: Optional[float] = None     # kg/day or %-point/day trend
    change: Optional[float] = None         # predicted - current
    clamped: Optional[bool] = None         # trend was capped to a safe range
    method: Optional[str] = None           # "ols-linear-regression" | "weighted-heuristic"
    note: Optional[str] = None             # why no forecast was produced
