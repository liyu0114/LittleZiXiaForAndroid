# Flutter SDK Download with Retry and Chunking
# Multiple methods with automatic retry

param(
    [int]$MaxRetries = 3
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Flutter SDK Installation (Multi-method)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$flutterPath = "C:\flutter"
$flutterBin = "$flutterPath\bin\flutter.bat"

if (Test-Path $flutterBin) {
    Write-Host "Flutter already installed" -ForegroundColor Green
    & $flutterBin --version
    exit 0
}

# Flutter download URLs (multiple sources)
$urls = @(
    @{
        Name = "Google Official"
        Url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.3-stable.zip"
    },
    @{
        Name = "Flutter CN (mirror)"
        Url = "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.3-stable.zip"
    },
    @{
        Name = "Tuna Mirror"
        Url = "https://mirrors.tuna.tsinghua.edu.cn/flutter/flutter_infra/releases/stable/windows/flutter_windows_3.19.3-stable.zip"
    }
)

$zipPath = "$env:TEMP\flutter.zip"
$downloaded = $false

# Method 1: Try with system proxy
Write-Host "[Method 1] Trying with system proxy..." -ForegroundColor Yellow

foreach ($urlInfo in $urls) {
    Write-Host "  Source: $($urlInfo.Name)" -ForegroundColor Gray
    Write-Host "  URL: $($urlInfo.Url)" -ForegroundColor Gray

    for ($i = 1; $i -le $MaxRetries; $i++) {
        Write-Host "  Attempt $i/$MaxRetries..." -ForegroundColor Gray

        try {
            # Use Invoke-WebRequest with timeout
            $ProgressPreference = 'SilentlyContinue'

            $response = Invoke-WebRequest `
                -Uri $urlInfo.Url `
                -OutFile $zipPath `
                -UseBasicParsing `
                -TimeoutSec 600 `
                -ErrorAction Stop

            $ProgressPreference = 'Continue'

            if (Test-Path $zipPath) {
                $fileSize = (Get-Item $zipPath).Length / 1MB
                if ($fileSize -gt 50) {  # Flutter SDK should be > 50MB
                    Write-Host "  ✓ Download successful! Size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green
                    $downloaded = $true
                    break
                } else {
                    Write-Host "  ✗ File too small, retrying..." -ForegroundColor Yellow
                    Remove-Item $zipPath -Force
                }
            }
        } catch {
            Write-Host "  ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }

    if ($downloaded) { break }
}

# Method 2: Try with explicit proxy
if (-not $downloaded) {
    Write-Host ""
    Write-Host "[Method 2] Trying with explicit proxy..." -ForegroundColor Yellow

    $proxy = "http://127.0.0.1:7897"

    foreach ($urlInfo in $urls) {
        Write-Host "  Source: $($urlInfo.Name)" -ForegroundColor Gray

        try {
            $ProgressPreference = 'SilentlyContinue'

            $response = Invoke-WebRequest `
                -Uri $urlInfo.Url `
                -OutFile $zipPath `
                -UseBasicParsing `
                -TimeoutSec 600 `
                -Proxy $proxy `
                -ProxyUseDefaultCredentials `
                -ErrorAction Stop

            $ProgressPreference = 'Continue'

            if (Test-Path $zipPath) {
                $fileSize = (Get-Item $zipPath).Length / 1MB
                if ($fileSize -gt 50) {
                    Write-Host "  ✓ Download successful! Size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green
                    $downloaded = $true
                    break
                }
            }
        } catch {
            Write-Host "  ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Method 3: Try chocolatey if available
if (-not $downloaded -and (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "[Method 3] Trying with Chocolatey..." -ForegroundColor Yellow

    try {
        choco install flutter -y
        if (Test-Path "C:\tools\flutter\bin\flutter.bat") {
            Write-Host "  ✓ Installed via Chocolatey" -ForegroundColor Green
            $downloaded = $true
        }
    } catch {
        Write-Host "  ✗ Chocolatey install failed" -ForegroundColor Red
    }
}

if (-not $downloaded) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "All download methods failed!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please download manually:" -ForegroundColor Yellow
    Write-Host "  1. Visit: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Cyan
    Write-Host "  2. Download ZIP file (~1GB)" -ForegroundColor Cyan
    Write-Host "  3. Extract to C:\flutter" -ForegroundColor Cyan
    Write-Host "  4. Add C:\flutter\bin to PATH" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# Extract
Write-Host ""
Write-Host "[Step 2/4] Extracting Flutter SDK..." -ForegroundColor Yellow

try {
    Expand-Archive -Path $zipPath -DestinationPath "C:\" -Force
    Write-Host "  ✓ Extracted successfully" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Extraction failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Configure environment
Write-Host ""
Write-Host "[Step 3/4] Configuring environment..." -ForegroundColor Yellow

[Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", "https://pub.flutter-io.cn", "User")
[Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", "https://storage.flutter-io.cn", "User")

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*C:\flutter\bin*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;C:\flutter\bin", "User")
    Write-Host "  ✓ Added to PATH" -ForegroundColor Green
}

# Cleanup
Write-Host ""
Write-Host "[Step 4/4] Cleaning up..." -ForegroundColor Yellow
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

# Verify
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Please restart your terminal and run:" -ForegroundColor Cyan
Write-Host "  flutter doctor" -ForegroundColor White
Write-Host ""
