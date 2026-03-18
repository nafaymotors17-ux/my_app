# Build release APK - run this in PowerShell or double-click
# APK output: build\app\outputs\flutter-apk\app-release.apk

Set-Location $PSScriptRoot

Write-Host "Building release APK (arm64 - works on most phones)..." -ForegroundColor Cyan
flutter build apk --release --target-platform android-arm64

if ($LASTEXITCODE -eq 0) {
    $apkPath = Join-Path $PSScriptRoot "build\app\outputs\flutter-apk\app-release.apk"
    Write-Host "`nDone! APK saved at:" -ForegroundColor Green
    Write-Host $apkPath -ForegroundColor Yellow
    explorer "/select,$apkPath"
} else {
    Write-Host "`nBuild failed. Check errors above." -ForegroundColor Red
    exit 1
}
