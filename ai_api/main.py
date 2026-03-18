from __future__ import annotations

from pathlib import Path
from typing import Any

import joblib
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field


APP_ROOT = Path(__file__).resolve().parent
REPO_ROOT = APP_ROOT.parent
MODELS_DIR = REPO_ROOT / "AI_MODELS"

VECTORIZER_PATH = MODELS_DIR / "tfidf_vectorizer.pkl"
# Your repo currently has one Naive Bayes model file; it is used for email/SMS text.
SMS_MODEL_PATH = MODELS_DIR / "email_phishing_model.pkl"


class SmsRequest(BaseModel):
    message: str = Field(..., min_length=1, description="SMS text to analyze")


class PredictionResponse(BaseModel):
    prediction: int
    result: str


app = FastAPI(title="Phishing Detector API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _load_joblib(path: Path) -> Any:
    if not path.exists():
        raise RuntimeError(f"Missing required model file: {path}")
    return joblib.load(path)


@app.on_event("startup")
def _startup_load_models() -> None:
    app.state.vectorizer = _load_joblib(VECTORIZER_PATH)
    app.state.sms_model = _load_joblib(SMS_MODEL_PATH)


@app.get("/")
def health() -> dict[str, str]:
    return {"status": "ok"}


def _normalize_text(text: str) -> str:
    # Keep this minimal; the TF-IDF vectorizer was trained with its own tokenization.
    return " ".join(text.strip().split())


@app.post("/check_sms", response_model=PredictionResponse)
def check_sms(req: SmsRequest) -> PredictionResponse:
    message = _normalize_text(req.message)
    if not message:
        raise HTTPException(status_code=400, detail="message must not be empty")

    vectorizer = app.state.vectorizer
    model = app.state.sms_model

    features = vectorizer.transform([message])
    pred = int(model.predict(features)[0])

    result = "Phishing" if pred == 1 else "Safe"
    return PredictionResponse(prediction=pred, result=result)


# Optional alias (matches the "recommended design" text you got)
@app.post("/check_message", response_model=PredictionResponse)
def check_message(req: SmsRequest) -> PredictionResponse:
    return check_sms(req)

