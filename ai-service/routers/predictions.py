from fastapi import APIRouter, HTTPException
from schemas import PredictionRequest, PredictionResult
from services.ml import predict_trend, retention_risk
from services import db
from datetime import datetime, timezone
from collections import Counter

router = APIRouter()

@router.post("/predictions", response_model=list[PredictionResult])
async def get_predictions(req: PredictionRequest):
    results = []
    try:
        mdata = db.select("body_measurements", "weight_kg, body_fat_pct, measured_at", member_id=req.member_id, order="measured_at.asc")
    except Exception:
        mdata = []
    if mdata:
        weights = [m.get("weight_kg", 0) for m in mdata if m.get("weight_kg")]
        if weights:
            pred = predict_trend(weights, req.days_ahead)
            results.append(PredictionResult(
                prediction_type="weight", current_value=weights[-1],
                predicted_value=pred["predicted_value"], unit="kg",
                days_ahead=req.days_ahead, confidence=pred["confidence"]
            ))
        bfs = [m.get("body_fat_pct", 0) for m in mdata if m.get("body_fat_pct")]
        if bfs:
            pred = predict_trend(bfs, req.days_ahead)
            results.append(PredictionResult(
                prediction_type="body_fat", current_value=bfs[-1],
                predicted_value=pred["predicted_value"], unit="%",
                days_ahead=req.days_ahead, confidence=pred["confidence"]
            ))
    try:
        att_data = db.select("attendance", "check_in_time", member_id=req.member_id, order="check_in_time.desc", limit=30)
    except Exception:
        att_data = []
    if att_data:
        weeks = Counter()
        for a in att_data:
            t = a.get("check_in_time", "")
            if t:
                try:
                    dt = datetime.fromisoformat(t.replace("Z", "+00:00"))
                    week = dt.isocalendar()[1]
                    weeks[week] += 1
                except Exception:
                    pass
        weekly_rates = [min(1, c / 7) for c in weeks.values()] if weeks else []
        last_seen = att_data[0].get("check_in_time", "")
        days_since = 999
        if last_seen:
            try:
                last = datetime.fromisoformat(last_seen.replace("Z", "+00:00"))
                days_since = (datetime.now(timezone.utc) - last).days
            except Exception:
                pass
        ret = retention_risk(weekly_rates, days_since)
        results.append(PredictionResult(
            prediction_type="retention_risk", current_value=weekly_rates[-1] if weekly_rates else 0.5,
            predicted_value=ret["score"], unit="score (0-1)",
            days_ahead=30, confidence=ret["score"]
        ))
    if not results:
        raise HTTPException(status_code=404, detail="Not enough data for predictions. Log measurements and attendance first.")
    return results
