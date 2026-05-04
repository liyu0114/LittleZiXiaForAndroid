# Flutter SDK Installation Script
# Using China mirrors for faster download

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Flutter SDK Installation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Set environment variables for China mirrors
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"

Write-Host "Using China mirrors:" -ForegroundColor Yellow
Write-Host "  PUB_HOSTED_URL: $env:PUB_HOSTED_URL" -ForegroundColor Gray
Write-Host "  FLUTTER_STORAGE_BASE_URL: $env:FLUTTER_STORAGE_BASE_URL" -ForegroundColor Gray
Write-Host ""

# Check if Flutter already exists
$flutterPath = "C:\flutter"
$flutterBin = "$flutterPath\bin\flutter.bat"

if (Test-Path $flutterBin) {
    Write-Host "Flutter already installed at $flutterPath" -ForegroundColor Green
    Write-Host "Checking version..." -ForegroundColor Yellow
    & $flutterBin --version
    exit 0
}

Write-Host "[Step 1/5] Downloading Flutter SDK..." -ForegroundColor Yellow
Write-Host ""

# Download URL (try multiple mirrors)
$urls = @(
    "https://mirrors.tuna.tsinghua.edu.cn/flutter/flutter_infra/releases/stable/windows/flutter_windows_3.19.3-stable.zip",
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.3-stable.zip"
)

$zipPath = "$env:TEMP\flutter.zip"
$downloaded = $false

foreach ($url in $urls) {
    Write-Host "  Trying: $url" -ForegroundColor Gray

    try {
        # Download with progress
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $zipPath)

        if (Test-Path $zipPath) {
            $downloaded = $true
            Write-Host "  Download successful!" -ForegroundColor Green
            break
        }
    } catch {
        Write-Host "  Download failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if (-not $downloaded) {
    Write-Host ""
    Write-Host "ERROR: Failed to download Flutter SDK" -ForegroundColor Red
    Write-Host "Please download manually from:" -ForegroundColor Yellow
    Write-Host "  https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Cyan
    exit 1
}

Write-Host ""
Write-Host "[Step 2/5] Extracting Flutter SDK..." -ForegroundColor Yellow
Write-Host "  Source: $zipPath" -ForegroundColor Gray
Write-Host "  Destination: C:\" -ForegroundColor Gray

try {
    # Extract to C:\
    Expand-Archive -Path $zipPath -DestinationPath "C:\" -Force

    # Verify extraction
    if (-not (Test-Path $flutterBin)) {
        throw "Extraction failed - flutter.bat not found"
    }

    Write-Host "  Extraction successful!" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Extraction failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[Step 3/5] Setting environment variables..." -ForegroundColor Yellow

# Set user environment variables
[Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", $env:PUB_HOSTED_URL, "User")
[Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", $env:FLUTTER_STORAGE_BASE_URL, "User")

# Add to PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*C:\flutter\bin*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;C:\flutter\bin", "User")
    Write-Host "  Added C:\flutter\bin to PATH" -ForegroundColor Green
} else {
    Write-Host "  C:\flutter\bin already in PATH" -ForegroundColor Gray
}

Write-Host ""
Write-Host "[Step 4/5] Cleaning up..." -ForegroundColor Yellow
Remove-Item $zipPath -Force
Write-Host "  Removed temporary file" -ForegroundColor Gray

Write-Host ""
Write-Host "[Step 5/5] Verifying installation..." -ForegroundColor Yellow

# Update PATH for current session
$env:Path = "$env:Path;C:\flutter\bin"

# Verify Flutter
Write-Host ""
& $flutterBin --version

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Flutter SDK installed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installation path: C:\flutter" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT: Close this terminal and open a new one to use Flutter!" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Open new terminal" -ForegroundColor White
Write-Host "  2. Run: flutter doctor" -ForegroundColor White
Write-Host "  3. Run: flutter doctor --android-licenses" -ForegroundColor White
Write-Host ""
