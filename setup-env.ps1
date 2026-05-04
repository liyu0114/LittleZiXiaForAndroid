# OpenClaw Mobile Development Environment Setup Script
# 自动安装 Flutter + Android SDK 开发环境

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OpenClaw Mobile Dev Environment Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 检查 Chocolatey
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "[1/5] Installing Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
} else {
    Write-Host "[1/5] Chocolatey already installed" -ForegroundColor Green
}

# 2. 安装 Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[2/5] Installing Git..." -ForegroundColor Yellow
    choco install git -y
} else {
    Write-Host "[2/5] Git already installed" -ForegroundColor Green
}

# 3. 安装 Java JDK 17
Write-Host "[3/5] Installing Java JDK 17..." -ForegroundColor Yellow
choco install openjdk17 -y

# 4. 安装 Android SDK
Write-Host "[4/5] Installing Android SDK..." -ForegroundColor Yellow
choco install android-sdk -y

# 5. 安装 Flutter SDK
$flutterPath = "C:\flutter"
if (-not (Test-Path $flutterPath)) {
    Write-Host "[5/5] Installing Flutter SDK..." -ForegroundColor Yellow
    
    # 下载 Flutter SDK
    $flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.3-stable.zip"
    $flutterZip = "$env:TEMP\flutter.zip"
    
    Write-Host "  Downloading Flutter SDK..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $flutterUrl -OutFile $flutterZip
    
    Write-Host "  Extracting Flutter SDK..." -ForegroundColor Gray
    Expand-Archive -Path $flutterZip -DestinationPath "C:\" -Force
    
    Remove-Item $flutterZip
} else {
    Write-Host "[5/5] Flutter SDK already installed" -ForegroundColor Green
}

# 6. 配置环境变量
Write-Host ""
Write-Host "[6/6] Configuring environment variables..." -ForegroundColor Yellow

$env:Path += ";C:\flutter\bin"
$env:Path += ";C:\Android\android-sdk\platform-tools"
$env:Path += ";C:\Android\android-sdk\tools"
$env:Path += ";C:\Android\android-sdk\tools\bin"

[Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Restart your terminal/PowerShell" -ForegroundColor White
Write-Host "2. Run: flutter doctor" -ForegroundColor White
Write-Host "3. Accept Android licenses: flutter doctor --android-licenses" -ForegroundColor White
Write-Host ""
