@echo off
chcp 65001 >nul
echo ========================================
echo Flutter SDK Installation (China Mirror)
echo ========================================
echo.

REM 设置国内镜像
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

echo Using China mirrors for faster download...
echo   PUB_HOSTED_URL=%PUB_HOSTED_URL%
echo   FLUTTER_STORAGE_BASE_URL=%FLUTTER_STORAGE_BASE_URL%
echo.

REM 检查是否已安装
if exist "C:\flutter\bin\flutter.bat" (
    echo Flutter already installed at C:\flutter
    echo Checking version...
    call C:\flutter\bin\flutter.bat --version
    goto :end
)

echo [Step 1/4] Downloading Flutter SDK from mirror...
echo.

REM 使用清华大学镜像下载
set FLUTTER_URL=https://mirrors.tuna.tsinghua.edu.cn/flutter/flutter_infra/releases/stable/windows/flutter_windows_3.19.3-stable.zip
set FLUTTER_ZIP=%TEMP%\flutter.zip

powershell -Command "& {Invoke-WebRequest -Uri '%FLUTTER_URL%' -OutFile '%FLUTTER_ZIP%' -UseBasicParsing}"

if not exist "%FLUTTER_ZIP%" (
    echo ERROR: Download failed from Tsinghua mirror
    echo Trying official mirror...
    set FLUTTER_URL=https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.3-stable.zip
    powershell -Command "& {Invoke-WebRequest -Uri '%FLUTTER_URL%' -OutFile '%FLUTTER_ZIP%' -UseBasicParsing}"
)

if not exist "%FLUTTER_ZIP%" (
    echo ERROR: Download failed
    goto :error
)

echo.
echo [Step 2/4] Extracting Flutter SDK to C:\flutter...
echo.

powershell -Command "& {Expand-Archive -Path '%FLUTTER_ZIP%' -DestinationPath 'C:\' -Force}"

echo.
echo [Step 3/4] Adding Flutter to system PATH...
echo.

REM 添加到系统 PATH（需要管理员权限）
powershell -Command "& {[Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';C:\flutter\bin', 'Machine')}"

REM 同时设置环境变量到用户级别
setx PATH "%PATH%;C:\flutter\bin"
setx PUB_HOSTED_URL "%PUB_HOSTED_URL%"
setx FLUTTER_STORAGE_BASE_URL "%FLUTTER_STORAGE_BASE_URL%"

echo.
echo [Step 4/4] Verifying installation...
echo.

REM 清理下载文件
del "%FLUTTER_ZIP%"

echo.
echo ========================================
echo Flutter SDK installed successfully!
echo ========================================
echo.
echo Installation path: C:\flutter
echo.
echo Environment variables set:
echo   PATH: C:\flutter\bin added
echo   PUB_HOSTED_URL: %PUB_HOSTED_URL%
echo   FLUTTER_STORAGE_BASE_URL: %FLUTTER_STORAGE_BASE_URL%
echo.
echo IMPORTANT: Close this terminal and open a new one to use Flutter!
echo.
echo Next steps:
echo   1. Open new terminal
echo   2. Run: flutter doctor
echo   3. Run: flutter doctor --android-licenses
echo.

goto :end

:error
echo.
echo ========================================
echo Installation failed!
echo ========================================
echo.
echo Please download manually:
echo   https://docs.flutter.dev/get-started/install/windows
echo.

:end
pause
