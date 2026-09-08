import os
from typing import Any

import httpx

_url = os.getenv("SUPABASE_URL")
_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not _url or not _key:
    raise RuntimeError("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY")

def _headers() -> dict[str, str]:
    return {
        "apikey": str(_key),
        "Authorization": f"Bearer {_key}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }

def select(table: str, columns: str = "*", **filters: Any) -> list[dict[str, Any]]:
    params = f"select={columns}"
    for k, v in filters.items():
        if v is not None:
            params += f"&{k}=eq.{v}"
    resp = httpx.get(f"{_url}/rest/v1/{table}?{params}", headers=_headers())
    resp.raise_for_status()
    return resp.json()  # type: ignore[return-value]

def select_single(table: str, columns: str = "*", **filters: Any) -> dict[str, Any] | None:
    rows = select(table, columns, **filters)
    return rows[0] if rows else None

def insert(table: str, data: dict[str, Any]) -> dict[str, Any] | None:
    resp = httpx.post(f"{_url}/rest/v1/{table}", headers=_headers(), json=data)
    resp.raise_for_status()
    parsed = resp.json()
    if isinstance(parsed, list) and parsed:
        return parsed[0]  # type: ignore[return-value]
    if isinstance(parsed, dict):
        return parsed
    return None
