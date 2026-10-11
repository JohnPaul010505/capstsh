import logging
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
    response body.

    Each generation is retained as a separate history row so admins can review
    how forecasts change over time.
    """
    try:
        predicted_date = (
            datetime.now(timezone.utc) + timedelta(days=result.days_ahead)
        ).date().isoformat()
        row = {
            "member_id": member_id,
            "metric_name": result.prediction_type,
            "predicted_value": result.predicted_value,
            "predicted_date": predicted_date,
            "confidence": result.confidence,
        }
        basis = {
            "current_value": result.current_value,
            "unit": result.unit,
            "data_points": result.data_points,
            "span_days": result.span_days,
            "date_from": (result.date_from or "")[:10] or None,
            "date_to": (result.date_to or "")[:10] or None,
            "daily_rate": result.daily_rate,
            "change": result.change,
            "clamped": result.clamped,
            "method": result.method,
            "note": result.note,
        }
        try:
            # Provenance columns come from migration 0030_prediction_basis.sql.
            db.insert("predictions", {**row, **basis})
        except Exception:
            # Migration not applied yet: still persist the forecast itself.
            logger.info("Prediction basis columns unavailable; storing forecast only")
            db.insert("predictions", row)
    except Exception as exc:
        logger.warning("Could not persist prediction for %s (%s): %s",
                       member_id, result.prediction_type, exc)


@router.post("/predictions", response_model=list[PredictionResult])
async def get_predictions(req: PredictionRequest):
    results: list[PredictionResult] = []
    notes: list[str] = []
    try:
        mdata = db.select("body_measurements", "weight_kg, measured_at", member_id=req.member_id, order="measured_at.asc")  # type: ignore[assignment]
    except Exception as exc:
        logger.warning("body_measurements unavailable for %s: %s", req.member_id, exc)
        mdata = []
    if mdata:
        weights = [m.get("weight_kg") for m in mdata]
        if any(v is not None for v in weights):
            # Weight only. Body fat is deliberately not forecast: no screen in
            # the system captures it, so the only values ever present came from
            # a dev seed script's random numbers.
            pred = predict_trend(weights, req.days_ahead, dates=[m.get("measured_at") for m in mdata])  # type: ignore[arg-type]
            if not pred.get("sufficient"):
                # A first reading is useful as a baseline, but cannot establish
                # a direction. Return it for display only; never save it as a forecast.
                if pred.get("data_points") == 1 and pred.get("current_value", 0) > 0:
                    results.append(PredictionResult(
                        prediction_type="weight",
                        current_value=pred["current_value"],
                        predicted_value=pred["current_value"],
                        unit="kg",
                        days_ahead=req.days_ahead,
                        confidence=0,
                        data_points=1,
                        span_days=0,
                        date_from=pred.get("date_from"),
                        date_to=pred.get("date_to"),
                        method="baseline-only",
                        sufficient=False,
                        note="Starting weight only — this is your baseline, not a trend forecast. Add 2 more weigh-ins spanning at least 7 days to see a forecast.",
                    ))
                else:
                    notes.append(f"Weight: {pred.get('reason')}")
            else:
                result = PredictionResult(
                    prediction_type="weight",
                    current_value=pred["current_value"],
                    predicted_value=pred["predicted_value"],
                    unit="kg",
                    days_ahead=req.days_ahead,
                    confidence=pred["confidence"],
                    data_points=pred.get("data_points"),
                    span_days=pred.get("span_days"),
                    date_from=pred.get("date_from"),
                    date_to=pred.get("date_to"),
                    daily_rate=pred.get("daily_rate"),
                    change=pred.get("change"),
                    clamped=pred.get("clamped"),
                    method=pred.get("method"),
                )
                results.append(result)
                _persist(req.member_id, result)
    try:
        att_data = db.select("attendance", "check_in_time", member_id=req.member_id, order="check_in_time.asc")  # type: ignore[assignment]
    except Exception as exc:
        logger.warning("attendance unavailable for %s: %s", req.member_id, exc)
        att_data = []
    valid_visits: list[datetime] = []
    for a in att_data:
        try:
            stamp = a.get("check_in_time")
            if stamp:
                dt = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
                valid_visits.append(dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt)
        except Exception:
            continue
    now = datetime.now(timezone.utc)
    if valid_visits:
        first_visit, last = min(valid_visits), max(valid_visits)
        completed_weeks = max(0, int((now - first_visit).total_seconds() // 604800))
        weekly_counts = [0] * completed_weeks
        for visit in valid_visits:
            week_index = int((visit - first_visit).total_seconds() // 604800)
            if 0 <= week_index < completed_weeks:
                weekly_counts[week_index] += 1
        weekly_rates = [min(1, count / 7) for count in weekly_counts]
        days_since = max(0, (now - last).days)
    else:
        first_visit = last = None
        completed_weeks = 0
        weekly_rates = []
        days_since = 0

    if completed_weeks < 4:
        note = (
            "No check-ins recorded yet. Retention estimates start after the first check-in and 4 completed weeks."
            if first_visit is None else
            f"Not enough attendance history yet: {completed_weeks} of 4 completed weeks. Retention risk will appear after 4 full weeks."
        )
        results.append(PredictionResult(
            prediction_type="retention_risk", current_value=0, predicted_value=0,
            unit="risk score (0-1)", days_ahead=30, confidence=0,
            data_points=completed_weeks, method="insufficient-history",
            sufficient=False, note=note,
        ))
    else:
        ret = retention_risk(weekly_rates, days_since)  # type: ignore[arg-type]
        risk_result = PredictionResult(
            prediction_type="retention_risk",
            current_value=weekly_rates[-1] if weekly_rates else 0.5,
            predicted_value=ret["score"],
            unit="risk score (0-1)",
            days_ahead=30,
            # Trust in the estimate (how much attendance history exists) -- not the
            # risk score, which used to render "high risk" as "high confidence".
            confidence=ret["confidence"],
            data_points=ret.get("data_points"),
            daily_rate=ret.get("weekly_rate"),
            method=ret.get("method"),
            sufficient=True,
            note=(
                f"60% check-in frequency + 20% falling trend + 20% recency "
                f"(last visit {days_since}d ago) - risk level {ret['risk']}"
                if days_since != 999 else
                "60% check-in frequency + 20% falling trend + 20% recency"
            ),
        )
        results.append(risk_result)
        _persist(req.member_id, risk_result)
    if not results:
        detail = "Not enough data for predictions. " + (
            " ".join(notes) if notes
            else "Log measurements and attendance first."
        )
        raise HTTPException(status_code=404, detail=detail)
    return results
