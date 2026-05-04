@echo off
echo ========================================
echo Flutter SDK Installation
echo ========================================
echo.

REM Check if Flutter already installed
if exist "C:\flutter\bin\flutter.bat" (
    echo Flutter already installed at C:\flutter
    echo Checking version...
    call C:\flutter\bin\flutter.bat --version
    goto :end
)

echo Installing Flutter SDK...
echo.

REM Download Flutter SDK
echo [1/3] Downloading Flutter SDK...
powershell -Command "& {Invoke-WebRequest -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.3-stable.zip' -OutFile '%TEMP%\flutter.zip'}"

if not exist "%TEMP%\flutter.zip" (
    echo ERROR: Download failed
    goto :error
)

REM Extract Flutter
echo [2/3] Extracting Flutter SDK to C:\flutter...
powershell -Command "& {Expand-Archive -Path '%TEMP%\flutter.zip' -DestinationPath 'C:\' -Force}"

REM Add to PATH
echo [3/3] Adding Flutter to PATH...
setx PATH "%PATH%;C:\flutter\bin" /M

echo.
echo ========================================
echo Flutter SDK installed successfully!
echo ========================================
echo.
echo Installation path: C:\flutter
echo.
echo Next steps:
echo   1. Close this terminal
echo   2. Open new terminal
echo   3. Run: flutter doctor
echo.

goto :end

:error
echo.
echo ========================================
echo Installation failed!
echo ========================================
echo Please check your internet connection and try again.
echo.

:end
pause
