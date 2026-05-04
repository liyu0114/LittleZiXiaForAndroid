# Flutter SDK Installation with Proxy
# Uses Clash Verge proxy for faster download

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Flutter SDK Installation (with Proxy)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Set environment variables for China mirrors
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"

# Configure proxy
$proxy = "http://127.0.0.1:7897"
Write-Host "Using proxy: $proxy" -ForegroundColor Yellow
Write-Host ""

# Check if Flutter already exists
$flutterPath = "C:\flutter"
$flutterBin = "$flutterPath\bin\flutter.bat"

if (Test-Path $flutterBin) {
    Write-Host "Flutter already installed at $flutterPath" -ForegroundColor Green
    & $flutterBin --version
    exit 0
}

Write-Host "[Step 1/5] Downloading Flutter SDK..." -ForegroundColor Yellow
Write-Host ""

# Download URL
$url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.3-stable.zip"
$zipPath = "$env:TEMP\flutter.zip"

Write-Host "  URL: $url" -ForegroundColor Gray
Write-Host "  Proxy: $proxy" -ForegroundColor Gray
Write-Host ""

try {
    # Create web client with proxy
    $webClient = New-Object System.Net.WebClient
    $webClient.Proxy = New-Object System.Net.WebProxy($proxy, $true)

    # Download with progress
    Write-Host "  Downloading... (this may take a few minutes)" -ForegroundColor Yellow

    $webClient.DownloadFile($url, $zipPath)

    if (Test-Path $zipPath) {
        $fileSize = (Get-Item $zipPath).Length / 1MB
        Write-Host "  Download successful! Size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green
    } else {
        throw "Download failed - file not found"
    }
} catch {
    Write-Host "  ERROR: Download failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please download manually:" -ForegroundColor Yellow
    Write-Host "  1. Visit: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Cyan
    Write-Host "  2. Download ZIP file" -ForegroundColor Cyan
    Write-Host "  3. Extract to C:\flutter" -ForegroundColor Cyan
    exit 1
}

Write-Host ""
Write-Host "[Step 2/5] Extracting Flutter SDK..." -ForegroundColor Yellow

try {
    Expand-Archive -Path $zipPath -DestinationPath "C:\" -Force

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
}

Write-Host ""
Write-Host "[Step 4/5] Cleaning up..." -ForegroundColor Yellow
Remove-Item $zipPath -Force
Write-Host "  Removed temporary file" -ForegroundColor Gray

Write-Host ""
Write-Host "[Step 5/5] Verifying installation..." -ForegroundColor Yellow
Write-Host ""

# Update PATH for current session
$env:Path = "$env:Path;C:\flutter\bin"

& $flutterBin --version

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Flutter SDK installed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installation path: C:\flutter" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Close this terminal and open a new one" -ForegroundColor White
Write-Host "  2. Run: flutter doctor" -ForegroundColor White
Write-Host "  3. Run: flutter doctor --android-licenses" -ForegroundColor White
Write-Host ""
