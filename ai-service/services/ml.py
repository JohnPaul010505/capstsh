import numpy as np
from sklearn.linear_model import LinearRegression
from typing import Any


def predict_trend(values: list[float], days_ahead: int = 30) -> dict[str, Any]:
    if len(values) < 2:
        return {"predicted_value": values[-1] if values else 0, "confidence": 0.0}
    x = np.arange(len(values)).reshape(-1, 1)
    y = np.array(values)
    model = LinearRegression()
    model.fit(x, y)
    future_x = np.arange(len(values), len(values) + days_ahead).reshape(-1, 1)
    preds = model.predict(future_x)
    r2 = model.score(x, y)
    return {
        "predicted_value": round(float(preds[-1]), 2),
        "trend": "up" if model.coef_[0] > 0 else "down",
        "confidence": round(max(0, min(1, r2)), 2),
        "daily_change": round(float(model.coef_[0]), 4),
    }


def retention_risk(attendance_rates: list[float], days_since_last_visit: int) -> dict[str, Any]:
    if not attendance_rates:
        return {"risk": "unknown", "score": 0.5}
    avg_rate = np.mean(attendance_rates)
    trend = np.polyfit(range(len(attendance_rates)), attendance_rates, 1)[0]
    score = 1 - (avg_rate * 0.6 + max(0, -trend) * 0.2 + min(1, days_since_last_visit / 30) * 0.2)
    score = max(0, min(1, score))
    return {"risk": "high" if score > 0.7 else "medium" if score > 0.4 else "low", "score": round(score, 2)}
