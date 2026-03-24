"""
Standalone SMS phishing API (FastAPI).
Run on your PC; point the Flutter app to http://<YOUR_PC_LAN_IP>:8000

Models go in: backend/models/
  - tfidf_vectorizer.pkl
  - email_phishing_model.pkl
"""
from __future__ import annotations

import ipaddress
import re
import warnings
import html as html_lib
import sys
import os
from bs4 import BeautifulSoup
from pathlib import Path
from typing import Any

import joblib
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

warnings.filterwarnings(
    "ignore",
    category=UserWarning,
    message=r".*does not have valid feature names.*",
)

# Make terminal printing reliable on Windows.
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

APP_ROOT = Path(__file__).resolve().parent
MODELS_DIR = APP_ROOT / "models"

VECTORIZER_PATH = MODELS_DIR / "tfidf_vectorizer.pkl"
SMS_MODEL_PATH = MODELS_DIR / "sms_rf_model (1) (1).pkl"
URL_MODEL_PATH = MODELS_DIR / "url_phishing_model.pkl"


def _ascii_preview(s: str, limit: int = 600) -> str:
    s = s.replace("\r", " ").replace("\n", " ")
    if len(s) > limit:
        s = s[:limit] + "..."
    # Keep only ASCII so Windows terminals won't crash with UnicodeEncodeError.
    return "".join((ch if ord(ch) < 128 else "?") for ch in s)


def _preview(s: str, limit: int = 600) -> str:
    s = s.replace("\r", " ").replace("\n", " ")
    if len(s) > limit:
        s = s[:limit] + "..."
    return s


class SmsRequest(BaseModel):
    message: str = Field(..., min_length=1, description="SMS text to analyze")


class EmailRequest(BaseModel):
    message: str = Field(..., min_length=1, description="Full email body (HTML or text)")


class PredictionResponse(BaseModel):
    prediction: int
    result: str


class UrlPrediction(BaseModel):
    url: str
    prediction: int
    result: str


class EmailCheckResponse(BaseModel):
    # Email text model output (naive bayes over TF-IDF)
    email_prediction: int
    email_result: str
    # URL model output (random forest over URL features)
    links: list[UrlPrediction]
    # Overall decision (phishing if email OR any link is phishing)
    overall_prediction: int
    overall_result: str


class EmailTextRequest(BaseModel):
    message: str = Field(..., min_length=1, description="Full email body (HTML or text)")


class UrlsRequest(BaseModel):
    urls: list[str]


class UrlLinksResponse(BaseModel):
    links: list[UrlPrediction]
    overall_prediction: int
    overall_result: str


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
    app.state.url_model = _load_joblib(URL_MODEL_PATH)


@app.get("/")
def health() -> dict[str, str]:
    return {"status": "ok"}

def _normalize_text(text: str) -> str:
    return " ".join(text.strip().split())


_URL_REGEX = re.compile(
    r"(?i)\b((?:https?://|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}/)[^\s<>()\[\]{}\"']+)"
)


def _strip_html(text: str) -> str:
    # Remove script/style blocks and then remove all tags.
    text = re.sub(r"(?is)<(script|style).*?>.*?</\1>", " ", text or "")
    text = re.sub(r"(?s)<[^>]+>", " ", text)
    return text


def _extract_urls(text: str) -> list[str]:
    src = text or ""
    try:
        soup = BeautifulSoup(src, "html.parser")
    except Exception:
        soup = None

    urls: list[str] = []
    if soup is not None:
        for a in soup.find_all("a"):
            href = a.get("href")
            if not href:
                continue
            url = str(href).strip()
            if not url:
                continue
            if url.lower().startswith("www"):
                url = f"http://{url}"
            if url.lower().startswith(("http://", "https://")):
                urls.append(url)

    # Fallback: plain-text URLs if HTML parsing fails or there are none.
    if not urls:
        for raw in _URL_REGEX.findall(src):
            url = raw.strip().rstrip(").,;!?:\"'")
            if url.lower().startswith("www"):
                url = f"http://{url}"
            if url.lower().startswith(("http://", "https://")):
                urls.append(url)

    # De-duplicate while keeping order and remove obvious non-link domains
    filtered: list[str] = []
    seen: set[str] = set()
    for u in urls:
        u_lower = u.lower()
        if "w3.org" in u_lower:
            continue
        if u_lower in seen:
            continue
        seen.add(u_lower)
        filtered.append(u)
    return filtered


def _html_to_text(text: str) -> str:
    """
    Convert HTML email to readable plain text.
    """
    src = text or ""
    try:
        soup = BeautifulSoup(src, "html.parser")
    except Exception:
        return _strip_html(src)

    for t in soup(["script", "style"]):
        try:
            t.decompose()
        except Exception:
            pass

    # Extract text with spacing so words don't run together.
    out = soup.get_text(" ", strip=True)
    out = html_lib.unescape(out)
    # Replace non-breaking/formatting characters with space.
    out = re.sub(r"[\u00A0\u2000-\u206F\uFEFF]+", " ", out)
    out = re.sub(r"\s+", " ", out)
    return out.strip()


def _remove_urls(text: str, urls: list[str]) -> str:
    cleaned = text
    for u in urls:
        cleaned = re.sub(re.escape(u), " ", cleaned, flags=re.IGNORECASE)
    return cleaned


def _normalize_for_email_model(text: str) -> str:
    # Email model expects cleaned text (TF-IDF features).
    text = _html_to_text(text)
    return _normalize_text(text.lower())


def _is_ip_address(host: str) -> bool:
    try:
        ipaddress.ip_address(host)
        return True
    except ValueError:
        return False


def _build_url_feature_vector(url: str, url_model: Any) -> np.ndarray:
    """
    Build URL feature vector matching the exact order expected by url_model.feature_names_in_.

    Some phishing-URL features are dataset-specific and require network/HTML scraping.
    In this app we set those to 0 so the URL model can still run.
    """
    url_lower = url.lower()

    scheme = ""
    if "://" in url_lower:
        scheme = url_lower.split("://", 1)[0]

    # Host (best-effort extraction)
    host = url_lower.split("://", 1)[-1].split("/", 1)[0].split("?", 1)[0]
    host = host.strip().lower()

    url_length = len(url)
    having_ip = 1.0 if _is_ip_address(host) else 0.0
    having_at = 1.0 if "@" in url else 0.0
    url_of_anchor = 1.0 if "#" in url else 0.0
    https_token = 1.0 if "https" in url_lower and not url_lower.startswith("https://") else 0.0

    double_slash_redirecting = 0.0
    if "://" in url:
        rest = url.split("://", 1)[1]
        double_slash_redirecting = 1.0 if "//" in rest else 0.0

    # Prefix/Suffix: hyphen in hostname
    prefix_suffix = 1.0 if "-" in host else 0.0

    # Subdomains: count of labels excluding last two (root+TLD)
    host_parts = [p for p in host.split(".") if p]
    having_sub_domain = float(max(0, len(host_parts) - 2)) if host_parts else 0.0

    has_shortener = 1.0 if any(
        s in url_lower for s in [
            "bit.ly",
            "tinyurl.com",
            "t.co",
            "goo.gl",
            "ow.ly",
            "buff.ly",
            "cutt.ly",
            "is.gd",
            "soo.gd",
        ]
    ) else 0.0

    ssl_final_state = 1.0 if scheme == "https" else 0.0

    # Port value: extract the explicit port if present in host:port
    port_value = 0.0
    if ":" in host:
        before_colon, after_colon = host.split(":", 1)
        if before_colon and after_colon.isdigit():
            port_value = float(int(after_colon))

    # Redirect: heuristic based on common query params/keywords
    redirect = 1.0 if any(k in url_lower for k in ["redirect", "url=", "dest=", "destination=", "next="]) else 0.0

    abnormal_url = 1.0 if any(c in url for c in ["..", "@@", "{", "}", "|", "\\"]) else 0.0
    submitting_to_email = 1.0 if "mailto:" in url_lower else 0.0

    features: dict[str, float] = {
        "having_IPhaving_IP_Address": having_ip,
        "URLURL_Length": float(url_length),
        "Shortining_Service": has_shortener,
        "having_At_Symbol": having_at,
        "double_slash_redirecting": double_slash_redirecting,
        "Prefix_Suffix": prefix_suffix,
        "having_Sub_Domain": having_sub_domain,
        "SSLfinal_State": ssl_final_state,
        "Domain_registeration_length": 0.0,
        "Favicon": 0.0,
        "port": port_value,
        "HTTPS_token": https_token,
        "Request_URL": 0.0,
        "URL_of_Anchor": url_of_anchor,
        "Links_in_tags": 0.0,
        "SFH": 0.0,
        "Submitting_to_email": submitting_to_email,
        "Abnormal_URL": abnormal_url,
        "Redirect": redirect,
        "on_mouseover": 0.0,
        "RightClick": 0.0,
        "popUpWidnow": 0.0,
        "Iframe": 0.0,
        "age_of_domain": 0.0,
        "DNSRecord": 0.0,
        "web_traffic": 0.0,
        "Page_Rank": 0.0,
        "Google_Index": 0.0,
        "Links_pointing_to_page": 0.0,
        "Statistical_report": 0.0,
    }

    ordered_names = list(getattr(url_model, "feature_names_in_", []))
    if ordered_names:
        vec = [float(features.get(name, 0.0)) for name in ordered_names]
    else:
        vec = [float(v) for v in features.values()]

    return np.array([vec], dtype=float)


@app.post("/check_sms", response_model=PredictionResponse)
def check_sms(req: SmsRequest) -> PredictionResponse:
    message = _normalize_text(req.message)
    if not message:
        raise HTTPException(status_code=400, detail="message must not be empty")

    vectorizer = app.state.vectorizer
    model = app.state.sms_model

    features = vectorizer.transform([message])
    pred = int(model.predict(features)[0])
    if PHISHING_THRESHOLD is not None and hasattr(model, "predict_proba"):
        proba = model.predict_proba(features)[0]
        if len(proba) >= 2:
            pred = 1 if float(proba[1]) >= PHISHING_THRESHOLD else 0

    result = "Phishing" if pred == 1 else "Safe"
    return PredictionResponse(prediction=pred, result=result)


@app.post("/check_message", response_model=PredictionResponse)
def check_message(req: SmsRequest) -> PredictionResponse:
    return check_sms(req)


@app.post("/check_email", response_model=EmailCheckResponse)
def check_email(req: EmailRequest) -> EmailCheckResponse:
    raw = req.message or ""
    # Debug: show what the email model actually sees (clean text), not raw HTML.
    print(
        _ascii_preview(
            f"[check_email] received_length={len(raw)} urls_detected={len(_extract_urls(raw))}",
            limit=200,
        )
    )

    normalized_email_text = _normalize_for_email_model(raw)
    urls = _extract_urls(raw)
    email_text_no_urls = _normalize_text(_remove_urls(normalized_email_text, urls))
    normalized_preview = _preview(normalized_email_text, 1200)
    email_no_urls_preview = _preview(email_text_no_urls, 1200)

    print(f"[check_email] normalized_preview={normalized_preview}")
    print(f"[check_email] email_text_no_urls_preview={email_no_urls_preview}")
    print(f"[check_email] first_urls={urls[:5]}")

    # Email model prediction (0=Safe, 1=Phishing)
    vectorizer = app.state.vectorizer
    email_model = app.state.sms_model
    email_features = vectorizer.transform([email_text_no_urls])
    email_pred = int(email_model.predict(email_features)[0])
    if PHISHING_THRESHOLD is not None and hasattr(email_model, "predict_proba"):
        proba = email_model.predict_proba(email_features)[0]
        if len(proba) >= 2:
            email_pred = 1 if float(proba[1]) >= PHISHING_THRESHOLD else 0
    email_result = "Phishing" if email_pred == 1 else "Safe"

    # URL model prediction for each extracted link
    url_model = app.state.url_model
    link_predictions: list[UrlPrediction] = []
    overall_pred = email_pred

    for u in urls:
        X = _build_url_feature_vector(u, url_model=url_model)
        pred = int(url_model.predict(X)[0])
        result = "Phishing Website" if pred == 1 else "Legitimate Website"
        link_predictions.append(UrlPrediction(url=u, prediction=pred, result=result))
        if pred == 1:
            overall_pred = 1

    overall_result = "Phishing" if overall_pred == 1 else "Safe"

    return EmailCheckResponse(
        email_prediction=email_pred,
        email_result=email_result,
        links=link_predictions,
        overall_prediction=overall_pred,
        overall_result=overall_result,
    )


@app.post("/check_email_text", response_model=PredictionResponse)
def check_email_text(req: EmailTextRequest) -> PredictionResponse:
    raw = req.message or ""
    normalized_email_text = _normalize_for_email_model(raw)
    urls = _extract_urls(raw)
    email_text_no_urls = _normalize_text(_remove_urls(normalized_email_text, urls))

    vectorizer = app.state.vectorizer
    email_model = app.state.sms_model
    email_features = vectorizer.transform([email_text_no_urls])
    email_pred = int(email_model.predict(email_features)[0])
    if PHISHING_THRESHOLD is not None and hasattr(email_model, "predict_proba"):
        proba = email_model.predict_proba(email_features)[0]
        if len(proba) >= 2:
            email_pred = 1 if float(proba[1]) >= PHISHING_THRESHOLD else 0
    result = "Phishing" if email_pred == 1 else "Safe"
    return PredictionResponse(prediction=email_pred, result=result)


@app.post("/check_urls", response_model=UrlLinksResponse)
def check_urls(req: UrlsRequest) -> UrlLinksResponse:
    url_model = app.state.url_model
    link_predictions: list[UrlPrediction] = []
    overall_pred = 0

    for u in req.urls:
        if not u:
            continue
        X = _build_url_feature_vector(u, url_model=url_model)
        pred = int(url_model.predict(X)[0])
        result = "Phishing Website" if pred == 1 else "Legitimate Website"
        link_predictions.append(
            UrlPrediction(url=u, prediction=pred, result=result)
        )
        if pred == 1:
            overall_pred = 1

    overall_result = "Phishing" if overall_pred == 1 else "Safe"
    return UrlLinksResponse(
        links=link_predictions,
        overall_prediction=overall_pred,
        overall_result=overall_result,
    )
