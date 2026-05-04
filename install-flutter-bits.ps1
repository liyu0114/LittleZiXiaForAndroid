# Flutter SDK Installation using BITS
# BITS is more reliable for large downloads

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Flutter SDK Installation (BITS)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$flutterPath = "C:\flutter"
$flutterBin = "$flutterPath\bin\flutter.bat"

if (Test-Path $flutterBin) {
    Write-Host "Flutter already installed" -ForegroundColor Green
    & $flutterBin --version
    exit 0
}

Write-Host "[Step 1/4] Downloading Flutter SDK using BITS..." -ForegroundColor Yellow
Write-Host ""

$url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.3-stable.zip"
$zipPath = "$env:TEMP\flutter.zip"

try {
    # Start BITS transfer
    Write-Host "  Starting download (background transfer)..." -ForegroundColor Gray
    Start-BitsTransfer -Source $url -Destination $zipPath -DisplayName "Flutter SDK" -Priority High

    if (Test-Path $zipPath) {
        $fileSize = (Get-Item $zipPath).Length / 1MB
        Write-Host "  Download complete! Size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green
    } else {
        throw "Download failed"
    }
} catch {
    Write-Host "  BITS failed, trying alternative method..." -ForegroundColor Yellow

    # Alternative: Invoke-WebRequest with progress
    try {
        Write-Host "  Using Invoke-WebRequest..." -ForegroundColor Gray

        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        $ProgressPreference = 'Continue'

        if (Test-Path $zipPath) {
            $fileSize = (Get-Item $zipPath).Length / 1MB
            Write-Host "  Download complete! Size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green
        } else {
            throw "Download failed"
        }
    } catch {
        Write-Host "  ERROR: All download methods failed" -ForegroundColor Red
        Write-Host ""
        Write-Host "Manual download required:" -ForegroundColor Yellow
        Write-Host "  URL: $url" -ForegroundColor Cyan
        Write-Host "  Save to: $zipPath" -ForegroundColor Cyan
        Write-Host "  Then extract to C:\flutter" -ForegroundColor Cyan
        exit 1
    }
}

Write-Host ""
Write-Host "[Step 2/4] Extracting..." -ForegroundColor Yellow

try {
    Expand-Archive -Path $zipPath -DestinationPath "C:\" -Force
    Write-Host "  Extracted to C:\flutter" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Extraction failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[Step 3/4] Setting environment variables..." -ForegroundColor Yellow

[Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", "https://pub.flutter-io.cn", "User")
[Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", "https://storage.flutter-io.cn", "User")

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*C:\flutter\bin*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;C:\flutter\bin", "User")
}

Write-Host "  Environment configured" -ForegroundColor Green

Write-Host ""
Write-Host "[Step 4/4] Cleaning up..." -ForegroundColor Yellow
Remove-Item $zipPath -Force

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Please restart terminal and run:" -ForegroundColor Cyan
Write-Host "  flutter doctor" -ForegroundColor White
Write-Host ""
