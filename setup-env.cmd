@echo off
echo ========================================
echo OpenClaw Mobile Dev Environment Setup
echo ========================================
echo.

echo Installing Flutter SDK to C:\flutter...
echo.

REM Download Flutter SDK
powershell -Command "Invoke-WebRequest -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.3-stable.zip' -OutFile '%TEMP%\flutter.zip'"

REM Extract Flutter
powershell -Command "Expand-Archive -Path '%TEMP%\flutter.zip' -DestinationPath 'C:\' -Force"

REM Add to PATH
setx PATH "%PATH%;C:\flutter\bin"

echo.
echo Flutter SDK installed to C:\flutter
echo.
echo Please restart your terminal and run:
echo   flutter doctor
echo.
pause
