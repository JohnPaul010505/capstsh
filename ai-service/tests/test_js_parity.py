"""Parity check: ai-service/services/ml.py vs the JS fallback in admin/server.

The two implementations must agree, otherwise the same member sees different
forecasts depending on whether the AI service happened to be running.  The JS
functions are extracted from the real source (never re-typed) so the check
cannot drift from the code under test.

Run: ``python tests/test_js_parity.py``  (node must be on PATH)
"""
import datetime as dt
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from services.ml import predict_trend, retention_risk  # noqa: E402

SERVER = os.path.join(os.path.dirname(ROOT), "admin", "server", "index.js")

# Fixtures shared by both implementations.
MONTHLY = [(dt.datetime(2026, 1, 12) + dt.timedelta(days=31 * i)).isoformat() for i in range(7)]
WEIGHTS = [50, 52, 54, 56, 58, 60, 62]
QUARTERLY = [(dt.datetime(2026, 1, 1) + dt.timedelta(days=30 * i)).isoformat() for i in range(4)]
WILD = [40.0, 55.0, 70.0, 90.0]

NUMERIC_FIELDS = ["predicted_value", "current_value", "change", "clamped", "confidence",
                  "r2", "daily_rate", "data_points", "span_days", "trend"]


def python_results() -> dict:
    return {
        "weight": predict_trend(WEIGHTS, 30, dates=MONTHLY),
        "clamped": predict_trend(WILD, 30, dates=QUARTERLY),
        "tooShort": predict_trend([61.0, 62.0], 30, dates=MONTHLY[:2]),
        "r1": retention_risk([1.0, 1.0, 1.0, 0.9, 1.0, 1.0], 1),
        "r2": retention_risk([1.0, 0.7, 0.4, 0.2], 25),
        "r3": retention_risk([0.0, 0.0, 0.0], 40),
    }


def js_results() -> dict:
    with open(SERVER, encoding="utf-8") as fh:
        source = fh.read()
    start = source.index("// --- Forecast math")
    end = source.index("function getWeekNumber")
    module_path = os.path.join(os.environ.get("TEMP", "."), "forecast_parity.js")
    with open(module_path, "w", encoding="utf-8") as fh:
        fh.write(source[start:end] + "\nmodule.exports={forecastTrend,retentionForecast};\n")
    script = """
const m = require(process.env.FORECAST_MODULE);
const iso = (y, mo, d) => new Date(Date.UTC(y, mo, d)).toISOString();
const monthly = [0,31,62,93,124,155,186].map(x => iso(2026,0,12+x));
const quarterly = [0,30,60,90].map(x => iso(2026,0,1+x));
const out = {
  weight: m.forecastTrend([50,52,54,56,58,60,62], monthly, 30),
  clamped: m.forecastTrend([40,55,70,90], quarterly, 30),
  tooShort: m.forecastTrend([61,62], monthly.slice(0,2), 30),
  r1: m.retentionForecast([1,1,1,0.9,1,1], 1),
  r2: m.retentionForecast([1,0.7,0.4,0.2], 25),
  r3: m.retentionForecast([0,0,0], 40),
};
console.log(JSON.stringify(out));
"""
    env = dict(os.environ, FORECAST_MODULE=module_path.replace("\\", "\\\\"))
    proc = subprocess.run(["node", "-e", script], capture_output=True, text=True, env=env)
    if proc.returncode != 0:
        raise RuntimeError(f"node failed: {proc.stderr.strip()}")
    return json.loads(proc.stdout)


def main() -> int:
    py = python_results()
    js = js_results()
    mismatches: list[str] = []
    for case, expected in py.items():
        actual = js.get(case, {})
        for field in NUMERIC_FIELDS:
            if field not in expected:
                continue
            want, got = expected[field], actual.get(field)
            if isinstance(want, (int, float)) and not isinstance(want, bool):
                if got is None or abs(float(want) - float(got)) > 1e-9:
                    mismatches.append(f"{case}.{field}: python={want} js={got}")
            elif str(want) != str(got):
                mismatches.append(f"{case}.{field}: python={want} js={got}")
        for field in ("risk", "score", "confidence", "sufficient", "reason"):
            if field in expected and field in actual:
                want, got = expected[field], actual[field]
                if isinstance(want, float):
                    if abs(want - float(got)) > 1e-9:
                        mismatches.append(f"{case}.{field}: python={want} js={got}")
                elif str(want) != str(got):
                    mismatches.append(f"{case}.{field}: python={want} js={got}")

    print("python vs JS fallback parity")
    for case in py:
        print(f"  {case}: python={py[case].get('predicted_value', py[case].get('score'))} "
              f"js={js.get(case, {}).get('predicted_value', js.get(case, {}).get('score'))}")
    if mismatches:
        print("\nMISMATCHES:")
        for m in mismatches:
            print(f"  {m}")
        return 1
    print("\nBoth paths agree on every field.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
