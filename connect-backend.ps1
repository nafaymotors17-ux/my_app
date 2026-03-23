param(
  [int]$Port = 8000
)

$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"

if (-not (Test-Path $adb)) {
  Write-Host "adb.exe not found at: $adb" -ForegroundColor Red
  Write-Host "Fix: install Android SDK Platform-Tools and/or update LOCALAPPDATA path." -ForegroundColor Yellow
  exit 1
}

Write-Host "Using adb: $adb"

& $adb start-server | Out-Host
& $adb devices | Out-Host

Write-Host "Forwarding USB: tcp:$Port -> tcp:$Port ..."
& $adb reverse "tcp:$Port" "tcp:$Port" | Out-Host

Write-Host "Current adb reverse rules:"
& $adb reverse --list | Out-Host

Write-Host "Backend PC check (http://127.0.0.1:$Port/):"
try {
  $res = Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:$Port/" -TimeoutSec 2
  $res | ConvertTo-Json -Compress | Write-Host
} catch {
  Write-Host "Backend not reachable from PC. Start FastAPI backend first." -ForegroundColor Yellow
}

