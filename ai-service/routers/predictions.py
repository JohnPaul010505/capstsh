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

    Re-generating replaces the member's previous forecast for the same metric
    *and* target date, so pressing Generate twice refreshes the row instead of
    stacking duplicates.
    """
    try:
        predicted_date = (
            datetime.now(timezone.utc) + timedelta(days=result.days_ahead)
        ).date().isoformat()
        db.delete(
            "predictions",
            member_id=member_id,
            metric_name=result.prediction_type,
            predicted_date=predicted_date,
        )
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
                # No invented number: tell the caller exactly what is missing.
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
        att_data = db.select("attendance", "check_in_time", member_id=req.member_id, order="check_in_time.desc", limit=30)  # type: ignore[assignment]
    except Exception as exc:
        logger.warning("attendance unavailable for %s: %s", req.member_id, exc)
        att_data = []
    if att_data:
        weeks: dict[int, list] = {}  # ISO week -> [check-ins, earliest check-in]
        for a in att_data:
            t = a.get("check_in_time", "")
            if not t:
                continue
            try:
                dt = datetime.fromisoformat(t.replace("Z", "+00:00"))
            except Exception:
                continue
            slot = weeks.setdefault(dt.isocalendar()[1], [0, dt])
            slot[0] += 1
            if dt < slot[1]:
                slot[1] = dt
        # Chronological order, not ISO week number: week numbers restart every
        # January, so week 1 of next year would otherwise sort before week 52 and
        # the "is attendance falling?" trend would read the series backwards.
        ordered = sorted(weeks.values(), key=lambda slot: slot[1])
        weekly_rates = [min(1, count / 7) for count, _ in ordered] if ordered else []
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
