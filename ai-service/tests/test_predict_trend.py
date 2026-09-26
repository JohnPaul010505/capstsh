"""Guard rails for the forecast math (run: ``python tests/test_predict_trend.py``).

These encode the bugs that produced absurd forecasts, so they cannot come back:
* "30 days ahead" must mean 30 *days*, not 30 more readings.
* a forecast may never exceed a physiologically plausible rate.
* a thin sample may never be reported as confident.
* the risk score is never allowed to masquerade as confidence.

Plain asserts so the file runs with or without pytest installed.
"""
import os
import sys
from datetime import datetime, timedelta

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.ml import (  # noqa: E402
    MAX_WEIGHT_CHANGE_PCT,
    predict_trend,
    retention_risk,
)

FAILURES: list[str] = []


def check(label: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  PASS  {label}")
    else:
        print(f"  FAIL  {label} {detail}")
        FAILURES.append(label)


def monthly_history(weights: list[float]) -> list[str]:
    """Readings on the 12th of consecutive months, as the seed scripts write them."""
    start = datetime(2026, 1, 12)
    return [(start + timedelta(days=31 * i)).isoformat() for i in range(len(weights))]


# --- the reported bug: 62 kg must never become 106.25 kg in 30 days ---------
def test_weight_forecast_is_realistic() -> None:
    print("weight forecast realism")
    dates = monthly_history([50, 52, 54, 56, 58, 60, 62])
    out = predict_trend([50, 52, 54, 56, 58, 60, 62], 30, dates=dates)
    check("sufficient history is forecastable", out.get("sufficient") is True, str(out))
    current, predicted = out["current_value"], out["predicted_value"]
    limit = current * MAX_WEIGHT_CHANGE_PCT
    check(
        "30-day change stays inside +/-5% of body weight",
        abs(predicted - current) <= limit + 1e-6,
        f"{current} -> {predicted} (limit +/-{limit:.2f})",
    )
    check("never reproduces the 106.25 kg bug", predicted < 70, f"got {predicted}")
    check("daily rate is a real kg/day slope", 0 < out["daily_rate"] < 0.1, str(out["daily_rate"]))
    check("fit quality is reported", 0 <= out["r2"] <= 1, str(out["r2"]))


# --- dates, not row indices, drive the projection ---------------------------
def test_dates_drive_the_projection() -> None:
    print("x-axis is elapsed time")
    base = datetime(2026, 3, 1)
    weekly = [(base + timedelta(days=7 * i)).isoformat() for i in range(4)]
    values = [60.0, 60.2, 60.4, 60.6]
    fast = predict_trend(values, 30, dates=weekly)
    monthly = predict_trend(values, 30, dates=monthly_history(values))
    check(
        "same readings spread further in time -> smaller 30-day move",
        fast["predicted_value"] > monthly["predicted_value"],
        f"weekly {fast['predicted_value']} vs monthly {monthly['predicted_value']}",
    )
    check("dense history is not over-projected by the clamp", fast["clamped"] is False, str(fast))


# --- sufficiency gate -------------------------------------------------------
def test_insufficient_history() -> None:
    print("insufficient data is reported, not invented")
    one = predict_trend([62.0], 30, dates=monthly_history([62.0]))
    check("single reading -> not forecastable", one.get("sufficient") is False, str(one))
    two = predict_trend([61.0, 62.0], 30, dates=monthly_history([61.0, 62.0]))
    check("two readings -> not forecastable", two.get("sufficient") is False, str(two))
    check("two readings explain what is needed", "at least" in two.get("reason", ""), two.get("reason", ""))
    dense_start = datetime(2026, 5, 1)
    dense = predict_trend(
        [60.0, 61.0, 62.0], 30,
        dates=[(dense_start + timedelta(days=2 * i)).isoformat() for i in range(3)],
    )
    check("three readings over 4 days -> not forecastable", dense.get("sufficient") is False, str(dense))
    empty = predict_trend([], 30, dates=[])
    check("no readings -> not forecastable", empty.get("sufficient") is False, str(empty))


# --- plausibility clamp -----------------------------------------------------
def test_clamp_keeps_forecasts_physical() -> None:
    print("plausibility clamp")
    dates = [(datetime(2026, 1, 1) + timedelta(days=30 * i)).isoformat() for i in range(4)]
    out = predict_trend([40.0, 55.0, 70.0, 90.0], 30, dates=dates)
    check("wild trend is flagged as clamped", out["clamped"] is True, str(out))
    current = out["current_value"]
    check(
        "clamped forecast respects the safe range",
        current * (1 - MAX_WEIGHT_CHANGE_PCT) <= out["predicted_value"] <= current * (1 + MAX_WEIGHT_CHANGE_PCT),
        str(out),
    )
    drop = predict_trend([90.0, 70.0, 55.0, 40.0], 30, dates=dates)
    check("a collapsing trend is capped downwards too", drop["clamped"] is True, str(drop))
    check(
        "downward cap holds",
        drop["current_value"] * (1 - MAX_WEIGHT_CHANGE_PCT) <= drop["predicted_value"],
        str(drop),
    )


# --- honest confidence ------------------------------------------------------
def test_confidence_reflects_sample_size() -> None:
    print("confidence honesty")
    thin = predict_trend([50.0, 55.0, 60.0], 30, dates=monthly_history([50.0, 55.0, 60.0]))
    check("three monthly readings are never 'high' confidence", thin["confidence"] < 0.7, str(thin["confidence"]))
    weights = [50 + i for i in range(8)]
    rich = predict_trend(weights, 30, dates=monthly_history(weights))
    check("eight months of data can reach high confidence", rich["confidence"] >= 0.7, str(rich["confidence"]))
    check("confidence is a 0-1 fraction", 0 <= rich["confidence"] <= 1, str(rich["confidence"]))
    # A perfectly linear seeded history has R^2 = 1.0, but "100% confidence" for a
    # 30-day forecast is false precision.
    check("a forecast is never reported as certain", rich["confidence"] <= 0.95, str(rich["confidence"]))


# --- retention risk ---------------------------------------------------------
def test_retention_risk() -> None:
    print("retention risk")
    active = retention_risk([1.0, 1.0, 1.0, 0.9, 1.0, 1.0], 1)
    lapsing = retention_risk([1.0, 0.7, 0.4, 0.2], 25)
    gone = retention_risk([0.0, 0.0, 0.0], 40)
    check("consistent daily attendee is low risk", active["risk"] == "low", str(active))
    check("declining attendance outranks an active member", lapsing["score"] > active["score"], str(lapsing))
    check("a member who stopped coming is high risk", gone["risk"] == "high", str(gone))
    check("confidence is not the risk score", lapsing["confidence"] != lapsing["score"], str(lapsing))
    check("confidence stays a 0-1 fraction", 0 <= lapsing["confidence"] <= 1, str(lapsing))
    unknown = retention_risk([], 10)
    check("no attendance -> unknown", unknown["risk"] == "unknown", str(unknown))
    # Regression: the raw score was classified before rounding, so 0.4004 risk
    # rendered as 0.40 "medium" for a perfectly consistent attendee.
    check("risk band uses the rounded score", retention_risk([1.0] * 6, 1)["risk"] == "low",
          str(retention_risk([1.0] * 6, 1)))


def main() -> int:
    for test in (
        test_weight_forecast_is_realistic,
        test_dates_drive_the_projection,
        test_insufficient_history,
        test_clamp_keeps_forecasts_physical,
        test_confidence_reflects_sample_size,
        test_retention_risk,
    ):
        test()
    print()
    if FAILURES:
        print(f"{len(FAILURES)} FAILED: {FAILURES}")
        return 1
    print("All forecast tests passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
