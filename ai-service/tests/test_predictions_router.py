"""Endpoint-level checks for ``POST /api/ai/predictions`` with a stubbed DB.

Runs without pytest and without a Supabase connection: ``services.db`` is
replaced before the router is imported, so this exercises the real request
handling -- what gets forecast, what gets persisted, and the 404 message a new
member sees.

Run: ``python tests/test_predictions_router.py``
"""
import asyncio
import os
import sys
import types
from datetime import datetime, timedelta

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

# --- stub the data layer before the router imports it -----------------------
CALLS: dict[str, list] = {"select": [], "insert": [], "delete": []}
ROWS: dict[str, list[dict]] = {}


def _fake_select(table, columns="*", order=None, limit=None, **filters):
    CALLS["select"].append({"table": table, "order": order, "limit": limit, "filters": filters})
    rows = ROWS.get(table, [])
    if order and "." in order:
        column, direction = order.split(".", 1)
        rows = sorted(rows, key=lambda r: r.get(column) or "", reverse=direction == "desc")
    return rows[:limit] if limit else rows


def _fake_insert(table, data):
    CALLS["insert"].append({"table": table, **data})
    return data


def _fake_delete(table, **filters):
    CALLS["delete"].append({"table": table, **filters})
    return 204


db_stub = types.ModuleType("services.db")
db_stub.select = _fake_select
db_stub.insert = _fake_insert
db_stub.delete = _fake_delete
sys.modules["services.db"] = db_stub
import services  # noqa: E402

services.db = db_stub  # type: ignore[attr-defined]

from routers.predictions import get_predictions  # noqa: E402
from schemas import PredictionRequest  # noqa: E402

FAILURES: list[str] = []


def check(label: str, condition: bool, detail: str = "") -> None:
    print(f"  {'PASS' if condition else 'FAIL'}  {label}" + ("" if condition else f" {detail}"))
    if not condition:
        FAILURES.append(label)


def reset(measurements: list[dict], attendance: list[dict] | None = None) -> None:
    CALLS["select"], CALLS["insert"], CALLS["delete"] = [], [], []
    ROWS.clear()
    ROWS["body_measurements"] = measurements
    ROWS["attendance"] = attendance or []


def monthly(count: int, start_weight: float, step: float) -> list[dict]:
    base = datetime(2026, 1, 12)
    return [
        {
            "weight_kg": start_weight + step * i,
            "body_fat_pct": 20 + 0.5 * i,
            "measured_at": (base + timedelta(days=31 * i)).isoformat(),
        }
        for i in range(count)
    ]


def call(days_ahead: int = 30):
    return asyncio.run(get_predictions(PredictionRequest(member_id="m1", days_ahead=days_ahead)))



def test_weight_forecast_flow() -> None:
    print("weight forecast endpoint")
    reset(monthly(7, 50, 2))
    results = call()
    weight = next(r for r in results if r.prediction_type == "weight")
    check("forecast is returned", weight is not None)
    check("current value is the latest reading", weight.current_value == 62.0, str(weight.current_value))
    check("forecast is plausible, not 106 kg", weight.predicted_value < 70, str(weight.predicted_value))
    check("unit is kg", weight.unit == "kg", weight.unit)
    check("explainability fields are populated", bool(weight.data_points and weight.date_from), str(weight))
    check("history span is reported in days", bool(weight.span_days and weight.span_days > 100), str(weight.span_days))
    check("daily trend rate is reported", weight.daily_rate is not None, str(weight))
    check("method is named", weight.method == "ols-linear-regression", str(weight.method))
    check(
        "oldest row is queried first",
        any(c["table"] == "body_measurements" and c["order"] == "measured_at.asc" for c in CALLS["select"]),
        str(CALLS["select"]),
    )
    check("forecast is persisted", any(c["table"] == "predictions" for c in CALLS["insert"]), str(CALLS["insert"]))
    stored = next(c for c in CALLS["insert"] if c["table"] == "predictions")
    check(
        "provenance is stored with the forecast",
        stored.get("data_points") == 7 and stored.get("method") == "ols-linear-regression" and stored.get("clamped") is False,
        str(stored),
    )
    check("history range is stored as dates", str(stored.get("date_from", "")).startswith("2026-01-12"), str(stored.get("date_from")))


def test_persist_survives_missing_migration() -> None:
    print("forecast is stored even without the 0030 migration")
    reset(monthly(7, 50, 2))
    calls: list[dict] = []
    original = _fake_insert

    def failing_insert(table, data):
        calls.append({"table": table, **data})
        if "data_points" in data:
            raise RuntimeError("column predictions.data_points does not exist")
        return original(table, data)

    import services.db as db_module

    db_module.insert = failing_insert
    try:
        call()
    finally:
        db_module.insert = original
    check("full row attempted first", "data_points" in calls[0], str(calls[:1]))
    fallback = [c for c in calls if "data_points" not in c]
    check("forecast still stored without basis", {c.get("metric_name") for c in fallback} == {"weight"}, str(fallback))
    check("fallback rows omit unknown columns", all("method" not in c for c in fallback), str(fallback))


def test_regenerate_replaces_duplicate() -> None:
    print("regenerating replaces the stored forecast")
    reset(monthly(7, 50, 2))
    call()
    check(
        "previous forecast for the same metric/date is deleted first",
        any(
            c["table"] == "predictions"
            and c.get("metric_name") == "weight"
            and c.get("member_id") == "m1"
            and "predicted_date" in c
            for c in CALLS["delete"]
        ),
        str(CALLS["delete"]),
    )


def test_insufficient_history_message() -> None:
    print("insufficient history is explained, not invented")
    reset([{"weight_kg": 61.0, "body_fat_pct": None, "measured_at": "2026-01-12T08:00:00+00:00"},
           {"weight_kg": 62.0, "body_fat_pct": None, "measured_at": "2026-02-12T08:00:00+00:00"}])
    try:
        call()
        check("404 raised for too little history", False, "no exception")
    except Exception as exc:  # HTTPException
        detail = getattr(exc, "detail", "")
        check("404 raised for too little history", getattr(exc, "status_code", 0) == 404, str(exc))
        check("message says what is needed", "at least 3 weigh-ins" in detail, detail)
        check("nothing was persisted", not CALLS["insert"], str(CALLS["insert"]))

    reset([])
    try:
        call()
        check("404 raised with no data at all", False, "no exception")
    except Exception as exc:
        check("404 raised with no data at all", getattr(exc, "status_code", 0) == 404, str(exc))


def test_retention_is_separate_from_confidence() -> None:
    print("retention risk")
    reset(monthly(5, 50, 2), attendance=[
        {"check_in_time": (datetime(2026, 3, 1) + timedelta(days=2 * i)).isoformat()}
        for i in range(14)
    ])
    results = call()
    risk = next(r for r in results if r.prediction_type == "retention_risk")
    check("risk is a 0-1 score", 0 <= risk.predicted_value <= 1, str(risk.predicted_value))
    check("confidence is not the risk score", risk.confidence != risk.predicted_value, str(risk))
    check("risk unit is labelled", "risk" in risk.unit, risk.unit)
    check("formula is explained to the UI", "check-in frequency" in (risk.note or ""), str(risk.note))
    check("weekly attendance rate is reported", risk.daily_rate is not None, str(risk))
    check("attendance is queried newest-first with a limit",
          any(c["table"] == "attendance" and c["order"] == "check_in_time.desc" and c["limit"] == 30
              for c in CALLS["select"]), str(CALLS["select"]))


def test_body_fat_is_not_forecast() -> None:
    print("body fat is never forecast")
    reset([
        {"weight_kg": w, "body_fat_pct": fat,
         "measured_at": (datetime(2026, 1, 1) + timedelta(days=30 * i)).isoformat()}
        for i, (w, fat) in enumerate([(60, 20), (61, 24), (62, 28), (63, 32)])
    ])
    results = call()
    metrics = {r.prediction_type for r in results}
    check("no body-fat forecast is produced", "body_fat" not in metrics, str(metrics))
    check("weight is still forecast", "weight" in metrics, str(metrics))
    check(
        "body_fat_pct is not even queried",
        all("body_fat_pct" not in str(c) for c in CALLS["select"]),
        str(CALLS["select"]),
    )


def main() -> int:
    for test in (
        test_weight_forecast_flow,
        test_persist_survives_missing_migration,
        test_regenerate_replaces_duplicate,
        test_insufficient_history_message,
        test_retention_is_separate_from_confidence,
        test_body_fat_is_not_forecast,
    ):
        test()
    print()
    if FAILURES:
        print(f"{len(FAILURES)} FAILED: {FAILURES}")
        return 1
    print("All prediction endpoint tests passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

