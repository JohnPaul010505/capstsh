from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import os
import uvicorn

load_dotenv()

# CORS: comma-separated origins, or "*" for any origin (mobile/native calls carry no cookies,
# so wildcard + allow_credentials=False is safe for the capstone deployment).
_raw_origins = os.getenv("CORS_ORIGINS", "*")
if _raw_origins.strip() == "*":
    _origins = ["*"]
else:
    _origins = [o.strip() for o in _raw_origins.split(",") if o.strip()]


from routers.food import router as food_router
from routers.predictions import router as predictions_router
from routers.identify_food import router as identify_food_router
from routers.met import router as met_router

app = FastAPI(title="FIT Sight AI Service")

app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)

app.include_router(food_router, prefix="/api/ai")
app.include_router(predictions_router, prefix="/api/ai")
app.include_router(identify_food_router, prefix="/api/ai")
app.include_router(met_router, prefix="/api/ai")

@app.get("/api/health")
def health():
    return {"status": "ok"}

if __name__ == "__main__":
    # Default 3001 keeps the admin Vite proxy ('/api' -> localhost:3001) and the mobile
    # API_BASE_URL fallback in agreement without extra config.
    uvicorn.run("main:app", host="0.0.0.0", port=int(os.getenv("PORT", "3001")), reload=True)
