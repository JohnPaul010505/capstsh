import logging
from collections import Counter
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, HTTPException

from schemas import PredictionRequest, PredictionResult
from services.ml import predict_trend, retention_risk
from services import db

logger = logging.getLogger(__name__)

router = APIRouter()


def _persist(member_id: str, result: PredictionResult) -> None:
    """Persist a forecast into the predictions table (Table 25) with the
    service role (DFD 4.1: prediction data are written into Predictions).
    Best-effort: a persistence failure must never lose the forecast in the
    response body."""
    try:
        predicted_date = (
            datetime.now(timezone.utc) + timedelta(days=result.days_ahead)
        ).date().isoformat()
        db.insert("predictions", {
            "member_id": member_id,
            "metric_name": result.prediction_type,
            "predicted_value": result.predicted_value,
            "predicted_date": predicted_date,
            "confidence": result.confidence,
        })
    except Exception as exc:
        logger.warning("Could not persist prediction for %s (%s): %s",
                       member_id, result.prediction_type, exc)


@router.post("/predictions", response_model=list[PredictionResult])
async def get_predictions(req: PredictionRequest):
    results = []
    try:
        mdata = db.select("body_measurements", "weight_kg, body_fat_pct, measured_at", member_id=req.member_id, order="measured_at.asc")  # type: ignore[assignment]
    except Exception:
        mdata = []
    if mdata:
        weights = [m.get("weight_kg", 0) for m in mdata if m.get("weight_kg")]
        if weights:
            pred = predict_trend([float(x) for x in weights], req.days_ahead)  # type: ignore[arg-type]
            weight_result = PredictionResult(
                prediction_type="weight", current_value=weights[-1],
                predicted_value=pred["predicted_value"], unit="kg",
                days_ahead=req.days_ahead, confidence=pred["confidence"]
            )
            results.append(weight_result)
            _persist(req.member_id, weight_result)
        bfs = [m.get("body_fat_pct", 0) for m in mdata if m.get("body_fat_pct")]
        if bfs:
            pred = predict_trend([float(x) for x in bfs], req.days_ahead)  # type: ignore[arg-type]
            fat_result = PredictionResult(
                prediction_type="body_fat", current_value=bfs[-1],
                predicted_value=pred["predicted_value"], unit="%",
                days_ahead=req.days_ahead, confidence=pred["confidence"]
            )
            results.append(fat_result)
            _persist(req.member_id, fat_result)
    try:
        att_data = db.select("attendance", "check_in_time", member_id=req.member_id, order="check_in_time.desc", limit=30)  # type: ignore[assignment]
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
        ret = retention_risk(weekly_rates, days_since)  # type: ignore[arg-type]
        risk_result = PredictionResult(
            prediction_type="retention_risk", current_value=weekly_rates[-1] if weekly_rates else 0.5,
            predicted_value=ret["score"], unit="score (0-1)",
            days_ahead=30, confidence=ret["score"]
        )
        results.append(risk_result)
        _persist(req.member_id, risk_result)
    if not results:
        raise HTTPException(status_code=404, detail="Not enough data for predictions. Log measurements and attendance first.")
    return results
