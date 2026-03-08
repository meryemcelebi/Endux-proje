from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging

app = FastAPI(title="Endux AI Service", version="1.0.0")

# Setup CORS for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@app.get("/health")
def read_health():
    
    logger.info("pig gonderildi")
    return {
        "status": "success",
        "service": "endux_ai_service",
        "message": "AI Service is up and running."
    }

# Placeholder for future predictive maintenance ML route
@app.post("/predict")
def make_prediction():
    return {"message": "tahmin modeli yok."}
