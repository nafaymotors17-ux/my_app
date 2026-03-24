"""
Standalone SMS phishing API (FastAPI).
Run on your PC; point the Flutter app to http://<YOUR_PC_LAN_IP>:8000

Models go in: backend/models/
  - tfidf_vectorizer.pkl
  - sms_rf_model (2).pkl
"""
from __future__ import annotations

import sys
import os
from pathlib import Path
from typing import Any

import joblib
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# Make terminal printing reliable on Windows.
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

APP_ROOT = Path(__file__).resolve().parent
MODELS_DIR = APP_ROOT / "models"

VECTORIZER_PATH = MODELS_DIR / "tfidf_vectorizer.pkl"
SMS_MODEL_PATH = MODELS_DIR / "sms_rf_model (2).pkl"


def _ascii_preview(s: str, limit: int = 600) -> str:
    s = s.replace("\r", " ").replace("\n", " ")
    if len(s) > limit:
        s = s[:limit] + "..."
    # Keep only ASCII so Windows terminals won't crash with UnicodeEncodeError.
    return "".join((ch if ord(ch) < 128 else "?") for ch in s)


class SmsRequest(BaseModel):
    message: str = Field(..., min_length=1, description="SMS text to analyze")


class PredictionResponse(BaseModel):
    prediction: int
    result: str
    phishing_probability: float | None = None


app = FastAPI(title="Phishing SMS API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

_threshold_env = os.getenv("PHISHING_THRESHOLD")
# If PHISHING_THRESHOLD is not set, we use the model's raw `predict()` output (no thresholding).
PHISHING_THRESHOLD = float(_threshold_env) if _threshold_env is not None else None


def _load_joblib(path: Path) -> Any:
    if not path.exists():
        raise RuntimeError(f"Missing model file: {path}")
    return joblib.load(path)


@app.on_event("startup")
def _startup_load_models() -> None:
    app.state.vectorizer = _load_joblib(VECTORIZER_PATH)
    app.state.sms_model = _load_joblib(SMS_MODEL_PATH)


@app.get("/")
def health() -> dict[str, str]:
    return {"status": "ok"}


def _normalize_text(text: str) -> str:
    return " ".join(text.strip().split())


def _predict_sms(message: str) -> PredictionResponse:
    message = _normalize_text(message)
    if not message:
        raise HTTPException(status_code=400, detail="message must not be empty")

    vectorizer = app.state.vectorizer
    model = app.state.sms_model

    features = vectorizer.transform([message])
    pred = int(model.predict(features)[0])
    phishing_proba: float | None = None
    if PHISHING_THRESHOLD is not None and hasattr(model, "predict_proba"):
        proba = model.predict_proba(features)[0]
        if len(proba) >= 2:
            phishing_proba = float(proba[1])
            pred = 1 if float(proba[1]) >= PHISHING_THRESHOLD else 0
    elif hasattr(model, "predict_proba"):
        proba = model.predict_proba(features)[0]
        if len(proba) >= 2:
            phishing_proba = float(proba[1])

    result = "Phishing" if pred == 1 else "Safe"
    print(_ascii_preview(f"[check_sms] message={message}", limit=300))
    if phishing_proba is not None:
        print(
            _ascii_preview(
                f"[check_sms] prediction={pred} result={result} phishing_proba={phishing_proba:.4f}",
                limit=300,
            )
        )
    else:
        print(_ascii_preview(f"[check_sms] prediction={pred} result={result}", limit=300))
    return PredictionResponse(
        prediction=pred,
        result=result,
        phishing_probability=phishing_proba,
    )


@app.post("/check_sms", response_model=PredictionResponse)
def check_sms(req: SmsRequest) -> PredictionResponse:
    return _predict_sms(req.message)


@app.post("/check_message", response_model=PredictionResponse)
def check_message(req: SmsRequest) -> PredictionResponse:
    return _predict_sms(req.message)
