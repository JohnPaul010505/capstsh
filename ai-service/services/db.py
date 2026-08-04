import os
import httpx
from typing import Any

_url = os.getenv("SUPABASE_URL")
_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not _url or not _key:
    raise RuntimeError("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY")

def _headers() -> dict[str, str]:
    return {
        "apikey": _key,
        "Authorization": f"Bearer {_key}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }

def select(table: str, columns: str = "*", **filters) -> list[dict]:
    params = f"select={columns}"
    for k, v in filters.items():
        if v is not None:
            params += f"&{k}=eq.{v}"
    resp = httpx.get(f"{_url}/rest/v1/{table}?{params}", headers=_headers())
    resp.raise_for_status()
    return resp.json()

def select_single(table: str, columns: str = "*", **filters) -> dict | None:
    rows = select(table, columns, **filters)
    return rows[0] if rows else None

def insert(table: str, data: dict) -> dict | None:
    resp = httpx.post(f"{_url}/rest/v1/{table}", headers=_headers(), json=data)
    resp.raise_for_status()
    parsed = resp.json()
    return parsed[0] if isinstance(parsed, list) and parsed else parsed
