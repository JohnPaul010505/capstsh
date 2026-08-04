from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import uvicorn

load_dotenv()

from routers.food import router as food_router
from routers.goals import router as goals_router
from routers.predictions import router as predictions_router

app = FastAPI(title="FIT Sight AI Service")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:5173", "http://localhost:8000"],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)

app.include_router(food_router, prefix="/api/ai")
app.include_router(goals_router, prefix="/api/ai")
app.include_router(predictions_router, prefix="/api/ai")

@app.get("/api/health")
def health():
    return {"status": "ok"}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
