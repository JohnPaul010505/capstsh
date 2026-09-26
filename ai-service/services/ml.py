"""Forecast models behind ``POST /api/ai/predictions``.

``predict_trend`` is an ordinary-least-squares linear regression over the
member's real measurement *dates* (never over row indices) and is deliberately
conservative, because the forecast is shown to members as fact:

* **Enough history or nothing.**  Fewer than ``MIN_POINTS`` measurements, or a
   history shorter than ``MIN_SPAN_DAYS``, yields ``sufficient: False`` with a
   human reason instead of a number.  Two points always draw a perfect straight
   line, so they may still be projected but can never be called confident.
* **Physiologically plausible.**  The 30-day change is clamped to
   ``MAX_WEIGHT_CHANGE_PCT`` of the current value (clinically ~0.5-1% of body
   weight per week).  This is what stops a noisy short trend from forecasting
   "62 kg -> 106 kg".
* **Honest confidence.**  Confidence blends the fit quality (R^2) with how much
   data the fit was built from, so a two- or three-point history can never be
   reported as high confidence.

``retention_risk`` is an explainable weighted heuristic (check-in frequency,
attendance trend, recency) rather than a fitted model, so the UI can explain it
line by line.  Its ``confidence`` reflects how much attendance history exists --
never the risk score itself, which would label a dangerous member "high
confidence".
"""
import numpy as np
from sklearn.linear_model import LinearRegression
from datetime import datetime
from typing import Any, Optional

# --- Data sufficiency -------------------------------------------------------
MIN_POINTS = 3          # measurements needed for a real trend
MIN_SPAN_DAYS = 7       # ... spread over at least this many days
FULL_SAMPLE_POINTS = 5  # sample size that counts as "plenty" for confidence
FULL_SAMPLE_DAYS = 28   # ~4 weeks of history that counts as "plenty"
MAX_CONFIDENCE = 0.95   # a forecast is never reported as certain

# --- Plausibility bounds ----------------------------------------------------
MAX_WEIGHT_CHANGE_PCT = 0.05       # +/-5% of body weight over the horizon
MIN_PLAUSIBLE_VALUE = 0.5          # never forecast a non-positive body metric

# --- Retention risk ---------------------------------------------------------
RISK_HIGH_ABOVE = 0.7
RISK_MEDIUM_ABOVE = 0.4
RETENTION_W_FREQUENCY = 0.6        # 60% how often they check in ...
RETENTION_W_TREND = 0.2            # ... 20% whether that is falling ...
RETENTION_W_RECENCY = 0.2          # ... 20% how long since the last visit
RETENTION_FULL_WEEKS = 6           # weeks of check-in history for full confidence


def _to_days(stamp: Any) -> Optional[float]:
    """Timestamp -> days since epoch. ``None`` when unparseable."""
    if stamp is None:
        return None
    if isinstance(stamp, (int, float)) and not isinstance(stamp, bool):
        return float(stamp) / 86400.0
    text = str(stamp).strip()
    if not text:
        return None
    text = text.replace("Z", "+00:00")
    parsed: Optional[datetime] = None
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        for fmt in ("%Y-%m-%d", "%Y/%m/%d", "%d-%m-%Y", "%d/%m/%Y"):
            try:
                parsed = datetime.strptime(text, fmt)
                break
            except ValueError:
                continue
    if parsed is None:
        return None
    return parsed.timestamp() / 86400.0


def predict_trend(
    values: list[float],
    days_ahead: int = 30,
    dates: Optional[list[Any]] = None,
) -> dict[str, Any]:
    """Project one body metric ``days_ahead`` days into the future.

    ``values``/``dates`` are the member's readings in chronological order.  The
    regression is fitted against *elapsed days* taken from ``dates``; a missing
    or unparseable date is the only case that falls back to treating readings as
    evenly spaced, and the plausibility clamp still applies there.
    """
    readings: list[tuple[float, Optional[float], Any]] = []
    for i, raw in enumerate(values):
        if raw is None:
            continue
        try:
            value = float(raw)
        except (TypeError, ValueError):
            continue
        if value <= 0:
            continue
        stamp = dates[i] if dates and i < len(dates) else None
        readings.append((value, _to_days(stamp), stamp))

    if not readings:
        return {"sufficient": False, "reason": "no measurements recorded yet",
                "data_points": 0, "current_value": 0.0}

    use_dates = all(day is not None for _, day, _ in readings) and len(readings) >= 2
    if use_dates:
        readings.sort(key=lambda row: row[1])  # type: ignore[arg-type]
    ys = [row[0] for row in readings]
    xs = [row[1] for row in readings] if use_dates else list(range(len(ys)))  # type: ignore[list-item]
    n = len(ys)
    current = ys[-1]
    span_days = (xs[-1] - xs[0]) if use_dates else 0.0  # type: ignore[operator]
    basis = {
        "current_value": round(current, 2),
        "data_points": n,
        "span_days": int(round(span_days)),
        "date_from": str(readings[0][2]) if readings[0][2] is not None else None,
        "date_to": str(readings[-1][2]) if readings[-1][2] is not None else None,
        "method": "ols-linear-regression",
    }

    if n < 2:
        return {**basis, "sufficient": False,
                "reason": f"only {n} measurement logged - at least 2 are needed"}
    if n < MIN_POINTS or (use_dates and span_days < MIN_SPAN_DAYS):
        return {**basis, "sufficient": False,
                "reason": f"needs at least {MIN_POINTS} weigh-ins over {MIN_SPAN_DAYS}+ days "
                          f"(has {n} over {int(round(span_days))}d)"}

    x = np.array(xs, dtype=float).reshape(-1, 1)  # type: ignore[arg-type]
    y = np.array(ys, dtype=float)
    model = LinearRegression()
    model.fit(x, y)
    slope = float(model.coef_[0])
    r2 = float(model.score(x, y))

    # Forecast at last reading + horizon. Using the fitted line (not the raw last
    # value) keeps the projection consistent with the reported trend.
    horizon = float(xs[-1]) + float(days_ahead)  # type: ignore[arg-type]
    raw_prediction = float(model.predict(np.array([[horizon]]))[0])

    # --- plausibility clamp ---------------------------------------------------
    # Body weight may move at most +/-5% in the horizon: the clinical safe rate
    # is roughly 0.5-1% of body weight per week.
    low = max(current * (1 - MAX_WEIGHT_CHANGE_PCT), MIN_PLAUSIBLE_VALUE)
    high = current * (1 + MAX_WEIGHT_CHANGE_PCT)
    predicted = min(max(raw_prediction, low), high)
    clamped = abs(predicted - raw_prediction) > 1e-9

    # --- honest confidence ----------------------------------------------------
    # R^2 alone would rate a 3-point history as a perfect fit, so it is scaled by
    # how much data the fit actually used (point count and time span).
    sample_factor = min(1.0, (n - 1) / (FULL_SAMPLE_POINTS - 1))
    span_factor = min(1.0, span_days / FULL_SAMPLE_DAYS) if use_dates else 0.5
    confidence = r2 * sample_factor * span_factor
    # Never claim certainty about a 30-day forecast: even a perfect R^2 on a
    # perfectly linear history is false precision, and "100% confidence" is not
    # a defensible answer in a panel.
    confidence = round(max(0.0, min(MAX_CONFIDENCE, confidence)), 2)

    return {
        **basis,
        "sufficient": True,
        "predicted_value": round(predicted, 2),
        "change": round(predicted - current, 2),
        "raw_prediction": round(raw_prediction, 2),
        "clamped": clamped,
        "confidence": confidence,
        "r2": round(r2, 3),
        "trend": "up" if slope > 0 else "down" if slope < 0 else "flat",
        "daily_rate": round(slope, 4) if use_dates else None,
    }


def retention_risk(attendance_rates: list[float], days_since_last_visit: int) -> dict[str, Any]:
    """Chance the member goes inactive in the next 30 days, as a 0-1 score.

    Kept as a transparent weighted heuristic (no fitted model) so the admin UI
    can show the three inputs and their weights.  ``confidence`` reports how
    much attendance history backs the estimate -- deliberately *not* the risk
    score, which previously made a high-risk member display as "high
    confidence".
    """
    rates = [float(r) for r in attendance_rates if r is not None]
    if not rates:
        return {"risk": "unknown", "score": 0.5, "confidence": 0.0,
                "data_points": 0, "method": "weighted-heuristic"}

    avg_rate = float(np.mean(rates))
    trend = float(np.polyfit(range(len(rates)), rates, 1)[0]) if len(rates) > 1 else 0.0
    score = 1 - (
        avg_rate * RETENTION_W_FREQUENCY
        + max(0.0, -trend) * RETENTION_W_TREND
        + min(1.0, days_since_last_visit / 30.0) * RETENTION_W_RECENCY
    )
    score = round(max(0.0, min(1.0, score)), 2)
    weeks = len(rates)
    confidence = max(0.3, min(1.0, weeks / RETENTION_FULL_WEEKS))

    # Classify the *rounded* score. Classifying the raw value let a 0.4004 risk
    # display as 0.40 "medium", mislabelling a perfectly consistent attendee.
    return {
        "risk": "high" if score > RISK_HIGH_ABOVE else "medium" if score > RISK_MEDIUM_ABOVE else "low",
        "score": score,
        "confidence": round(confidence, 2),
        "data_points": weeks,
        "weekly_rate": round(avg_rate, 3),
        "days_since_last_visit": int(days_since_last_visit),
        "method": "weighted-heuristic",
    }

