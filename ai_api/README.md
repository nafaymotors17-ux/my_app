# Phishing Detector API (SMS model only)

This folder runs your existing TF‑IDF + Naive Bayes model (`.pkl`) using FastAPI.

## 1) Install (Windows / PowerShell)

### Install Python (one-time)

Your PC must have **Python 3.10+** installed.

Fastest option (recommended) using `winget`:

```powershell
winget install -e --id Python.Python.3.11
```

Then close and reopen PowerShell, and confirm:

```powershell
python --version
```

If PowerShell still says “Python was not found…”, disable the Windows “App execution alias” for Python:
- Settings → Apps → Advanced app settings → App execution aliases → turn **OFF** `python.exe` / `python3.exe`

### Create venv + install dependencies

From the repo root (`D:\my project\my_app`):

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r .\ai_api\requirements.txt
```

## 2) Run

```powershell
uvicorn ai_api.main:app --reload --host 0.0.0.0 --port 8000
```

## 3) Test (PowerShell)

```powershell
$body = @{ message = "Your bank account will be suspended. Verify now." } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8000/check_sms" -ContentType "application/json" -Body $body
```

Expected response:

```json
{ "prediction": 1, "result": "Phishing" }
```

## Endpoints

- `GET /` health check
- `POST /check_sms` body: `{ "message": "..." }`
- `POST /check_message` same as above (alias)

