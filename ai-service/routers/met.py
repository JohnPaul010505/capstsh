from fastapi import APIRouter, HTTPException, Query
from supabase import create_client  # type: ignore
import os
import google.generativeai as genai  # type: ignore
import json
import re
from pydantic import BaseModel
from typing import Optional, Any

router = APIRouter()

supabase_url = os.getenv("SUPABASE_URL")
service_role_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
google_api_key = os.getenv("GOOGLE_API_KEY")

if not supabase_url or not service_role_key:
    raise RuntimeError("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY")

supabase = create_client(supabase_url, service_role_key)  # type: ignore

if google_api_key:
    genai.configure(api_key=google_api_key)  # type: ignore

CATEGORIES = [
    "Chest", "Back", "Shoulders", "Biceps", "Triceps",
    "Legs", "Core", "Cardio Machines", "Functional Training",
    "CrossFit / HIIT", "Bodyweight", "Mobility & Recovery"
]

class MetExerciseResponse(BaseModel):
    id: str
    name: str
    category: str
    met_value: float
    is_ai_estimated: bool
    is_verified: bool
    confidence: Optional[float] = None

class SearchMetResponse(BaseModel):
    matches: list[MetExerciseResponse]

class EstimateMetRequest(BaseModel):
    exercise_name: str

class EstimateMetResponse(BaseModel):
    exercise: MetExerciseResponse
    source: str

class VerifyMetRequest(BaseModel):
    met_value: Optional[float] = None
    category: Optional[str] = None

class VerifyMetResponse(BaseModel):
    exercise: MetExerciseResponse

@router.get("/search-met", response_model=SearchMetResponse)
async def search_met(q: str = Query(..., min_length=2)):
    if len(q.strip()) < 2:
        return SearchMetResponse(matches=[])
    
    try:
        result = supabase.rpc("search_met_exercises", {  # type: ignore[attr-defined]
            "search_query": q,
            "similarity_threshold": 0.4,
            "match_limit": 10
        }).execute()
        
        matches = []
        for row in (result.data or []):
            row_data: dict[str, Any] = row
            matches.append(MetExerciseResponse(
                id=row_data["id"],
                name=row_data["name"],
                category=row_data["category"],
                met_value=float(row_data["met_value"]),
                is_ai_estimated=row_data["is_ai_estimated"],
                is_verified=row_data["is_verified"],
                confidence=float(row_data["confidence"]) if row_data["confidence"] is not None else None,
            ))
        
        return SearchMetResponse(matches=matches)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")

@router.post("/estimate-met", response_model=EstimateMetResponse)
async def estimate_met(request: EstimateMetRequest):
    exercise_name = request.exercise_name.strip()
    if not exercise_name:
        raise HTTPException(status_code=400, detail="exercise_name is required")
    
    # 1. Check for exact match first
    try:
        # type: ignore[attr-defined]
        existing = supabase.from_("met_exercises") \
            .select("*")\
            .ilike("name", exercise_name)\
            .limit(1)\
            .execute()
        
        if existing.data and len(existing.data) > 0:
            row_data: dict[str, Any] = existing.data[0]
            return EstimateMetResponse(
                exercise=MetExerciseResponse(
                    id=row_data["id"],
                    name=row_data["name"],
                    category=row_data["category"],
                    met_value=float(row_data["met_value"]),
                    is_ai_estimated=row_data["is_ai_estimated"],
                    is_verified=row_data["is_verified"],
                    confidence=float(row_data["confidence"]) if row_data["confidence"] is not None else None,
                ),
                source="existing"
            )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database check failed: {str(e)}")
    
    # 2. Call Gemini for estimation
    if not google_api_key:
        raise HTTPException(status_code=503, detail="AI service not configured")
    
    try:
        model = genai.GenerativeModel("gemini-1.5-flash")  # type: ignore
        categories_str = ", ".join(CATEGORIES)
        prompt = f"""
You are an exercise science assistant. Classify the exercise "{exercise_name}" into one of these categories:
{categories_str}

Return strict JSON only:
{{
  "name": "{exercise_name}",
  "category": "<best_fit_category>",
  "met_value": <float between 1.0 and 20.0>,
  "confidence": <float between 0.0 and 1.0>
}}

MET values reference Compendium of Physical Activities (Ainsworth et al.).
"""
        
        response = model.generate_content(prompt)  # type: ignore
        text = response.text.strip()
        
        # Extract JSON from response
        match = re.search(r'\{.*\}', text, re.DOTALL)
        if not match:
            raise HTTPException(status_code=500, detail="AI returned invalid response format")
        
        data: dict[str, Any] = json.loads(match.group())
        
        # Validate required fields
        if "category" not in data or "met_value" not in data or "confidence" not in data:
            raise HTTPException(status_code=500, detail="AI response missing required fields")
        
        if data["category"] not in CATEGORIES:
            data["category"] = "General"
        
        # Clamp values
        data["met_value"] = max(1.0, min(20.0, float(data["met_value"])))
        data["confidence"] = max(0.0, min(1.0, float(data["confidence"])))

        # Reject low-confidence estimates
        if data["confidence"] < 0.4:
            raise HTTPException(status_code=400, detail="Exercise name doesn't appear to be a real exercise")

    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail="AI response not valid JSON")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI estimation failed: {str(e)}")
    
    # 3. Insert into database
    try:
        insert_result = supabase.from_("met_exercises").insert({  # type: ignore[attr-defined]
            "name": data["name"],
            "category": data["category"],
            "met_value": data["met_value"],
            "is_ai_estimated": True,
            "is_verified": False,
            "confidence": data["confidence"]
        }).execute()
        
        if not insert_result.data or len(insert_result.data) == 0:
            raise HTTPException(status_code=500, detail="Failed to insert exercise")
        
        row_data: dict[str, Any] = insert_result.data[0]
        return EstimateMetResponse(
            exercise=MetExerciseResponse(
                id=row_data["id"],
                name=row_data["name"],
                category=row_data["category"],
                met_value=float(row_data["met_value"]),
                is_ai_estimated=row_data["is_ai_estimated"],
                is_verified=row_data["is_verified"],
                confidence=float(row_data["confidence"]) if row_data["confidence"] is not None else None,
            ),
            source="ai_estimated"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database insert failed: {str(e)}")

@router.patch("/verify-met/{exercise_id}", response_model=VerifyMetResponse)
async def verify_met(exercise_id: str, request: VerifyMetRequest):
    # In a real implementation, get user_id from auth context
    # For now, we'll use a placeholder - in production this would come from the auth middleware
    user_id = "00000000-0000-0000-0000-000000000000"  # placeholder
    
    update_data: dict[str, Any] = {
        "is_verified": True,
        "verified_by": user_id,
        "verified_at": "now()"
    }
    
    if request.met_value is not None:
        update_data["met_value"] = request.met_value
    if request.category is not None:
        update_data["category"] = request.category
    
    try:
        # type: ignore[attr-defined]
        result = supabase.from_("met_exercises") \
            .update(update_data)\
            .eq("id", exercise_id)\
            .execute()
        
        if not result.data or len(result.data) == 0:
            raise HTTPException(status_code=404, detail="Exercise not found")
        
        row_data: dict[str, Any] = result.data[0]
        return VerifyMetResponse(
            exercise=MetExerciseResponse(
                id=row_data["id"],
                name=row_data["name"],
                category=row_data["category"],
                met_value=float(row_data["met_value"]),
                is_ai_estimated=row_data["is_ai_estimated"],
                is_verified=row_data["is_verified"],
                confidence=float(row_data["confidence"]) if row_data["confidence"] is not None else None,
            )
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Verification failed: {str(e)}")