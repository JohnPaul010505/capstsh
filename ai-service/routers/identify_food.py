from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, HttpUrl
from typing import Literal, List
import os
import httpx
import json
import logging
from io import BytesIO
import numpy as np
from PIL import Image as PILImage

import google.generativeai as genai

from services import db

logger = logging.getLogger(__name__)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
BLUR_THRESHOLD = float(os.getenv("BLUR_THRESHOLD", "100.0"))
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel("gemini-3.6-flash")


class IdentifyFoodRequest(BaseModel):
    image_url: str
    top_k: int = 3


class Candidate(BaseModel):
    name: str
    confidence: float
    serving_label: str | None = None
    serving_size_g: float | None = None
    calories_kcal: float | None = None
    protein_g: float | None = None
    carbs_g: float | None = None
    fat_g: float | None = None
    source: str | None = None
    matched: bool = False


class IdentifyFoodResponse(BaseModel):
    candidates: List[Candidate]
    step: str = "nutrition_matched"
    progress_percent: int = 100


router = APIRouter()


def _is_blurry(image: PILImage.Image, threshold: float = BLUR_THRESHOLD) -> bool:
    gray = image.convert("L").resize((50, 50))
    arr = np.array(gray, dtype=np.float32)
    laplacian = (
        np.roll(arr, 1, axis=0)
        + np.roll(arr, -1, axis=0)
        + np.roll(arr, 1, axis=1)
        + np.roll(arr, -1, axis=1)
        - 4.0 * arr
    )
    return float(laplacian.var()) < threshold


def _build_nutrition_lookup() -> dict[str, dict]:
    try:
        rows = db.select("nutrition_foods", "food_name,aliases,category,serving_label,serving_size_g,calories_kcal,protein_g,carbs_g,fat_g,source")
    except Exception:
        rows = []
    lookup: dict[str, dict] = {}
    for row in rows:
        name = (row.get("food_name") or "").strip().lower()
        if name:
            lookup[name] = row
        for alias in (row.get("aliases") or []):
            alias_str = str(alias).strip().lower()
            if alias_str:
                lookup[alias_str] = row
    return lookup


def _match_nutrition(name: str, lookup: dict[str, dict]) -> dict | None:
    key = name.strip().lower()
    return lookup.get(key)


@router.post("/identify-food", response_model=IdentifyFoodResponse)
async def identify_food(req: IdentifyFoodRequest):
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY not configured")

    if not req.image_url:
        raise HTTPException(status_code=400, detail="image_url is required")

    # Fetch image bytes
    try:
        async with httpx.AsyncClient(follow_redirects=True, timeout=30) as client:
            resp = await client.get(req.image_url)
            resp.raise_for_status()
            image_bytes = resp.content
    except Exception as e:
        logger.error("Failed to fetch image for food identification: %s", e)
        raise HTTPException(status_code=400, detail=f"Failed to fetch image: {e}")

    # Load image
    try:
        img = PILImage.open(BytesIO(image_bytes))
    except Exception as e:
        logger.error("Failed to load image: %s", e)
        raise HTTPException(status_code=400, detail="Invalid image data")

    if _is_blurry(img):
        raise HTTPException(status_code=400, detail="Image is too blurry, please retake the photo")

    # Build known foods list for prompt constraint
    try:
        rows = db.select("nutrition_foods", "food_name")
        known_foods = [r["food_name"] for r in rows if r.get("food_name")]
    except Exception:
        known_foods = []

    foods_text = ", ".join(known_foods) if known_foods else "(no seeded foods yet)"

    prompt = f"""You are identifying a food item from a photo for a Filipino fitness app.

Known foods (prefer matching one of these if the image resembles it):
{foods_text}

Analyze the attached image and return the top {req.top_k} most likely food matches as JSON only, no other text:
{{
  "candidates": [
    {{"name": "<food name, prefer an exact match from the known foods list>", "confidence": <0.0-1.0>}},
    ...
  ]
}}

If the food is not in the known list, still return your best guess for "name" but note it may need manual entry."""

    nutrition_lookup = _build_nutrition_lookup()

    try:
        response = model.generate_content([prompt, img])
        text = response.text.strip()
    except Exception as e:
        logger.error("Gemini vision error: %s", e)
        raise HTTPException(status_code=502, detail=f"Vision model error: {e}")

    # Extract JSON from response
    candidates_raw = []
    try:
        parsed = json.loads(text)
        candidates_raw = parsed.get("candidates", [])
    except json.JSONDecodeError:
        start = text.find("{")
        end = text.rfind("}")
        if start != -1 and end != -1 and end > start:
            try:
                parsed = json.loads(text[start:end + 1])
                candidates_raw = parsed.get("candidates", [])
            except json.JSONDecodeError:
                pass

    if not candidates_raw:
        raise HTTPException(status_code=502, detail="Vision model returned no candidates")

    results: list[Candidate] = []
    for c in candidates_raw[: req.top_k]:
        name = str(c.get("name", "")).strip()
        confidence = float(c.get("confidence", 0.0))
        nutrition = _match_nutrition(name, nutrition_lookup)
        results.append(Candidate(
            name=name,
            confidence=confidence,
            serving_label=nutrition.get("serving_label") if nutrition else None,
            serving_size_g=float(nutrition["serving_size_g"]) if nutrition and nutrition.get("serving_size_g") is not None else None,
            calories_kcal=float(nutrition["calories_kcal"]) if nutrition and nutrition.get("calories_kcal") is not None else None,
            protein_g=float(nutrition["protein_g"]) if nutrition and nutrition.get("protein_g") is not None else None,
            carbs_g=float(nutrition["carbs_g"]) if nutrition and nutrition.get("carbs_g") is not None else None,
            fat_g=float(nutrition["fat_g"]) if nutrition and nutrition.get("fat_g") is not None else None,
            source=nutrition.get("source") if nutrition else None,
            matched=nutrition is not None,
        ))

    return IdentifyFoodResponse(candidates=results, step="nutrition_matched", progress_percent=100)
