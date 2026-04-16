@echo off
cd /d "%~dp0"
echo Building release APK (arm64)...
call flutter build apk --release --target-platform android-arm64
if %ERRORLEVEL% equ 0 (
    echo.
    echo Done! APK: build\app\outputs\flutter-apk\app-release.apk
    start "" "build\app\outputs\flutter-apk"
) else (
    echo Build failed.
    pause
    exit /b 1
)
pause
