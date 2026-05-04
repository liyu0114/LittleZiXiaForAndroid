# OpenClaw Mobile APP 自动构建和部署脚本
# 用法: .\build-and-deploy.ps1 [-Version "1.3.0"] [-Deploy]

param(
    [string]$Version = "1.2.0",
    [switch]$Deploy = $false
)

$ErrorActionPreference = "Stop"

Write-Host "🦞 OpenClaw Mobile APP 自动构建脚本" -ForegroundColor Cyan
Write-Host "版本: $Version" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Cyan

# 设置路径
$ProjectRoot = "D:\mobile-client"
$AppPath = "$ProjectRoot\openclaw_app"
$SdkPath = "$ProjectRoot\openclaw_sdk"
$OutputPath = "D:\desktop"
$FlutterPath = "D:\flutter\flutter\bin\flutter.bat"

# 更新版本号
Write-Host "`n📝 更新版本号到 $Version..." -ForegroundColor Yellow

# 更新 pubspec.yaml
$PubspecPath = "$AppPath\pubspec.yaml"
$PubspecContent = Get-Content $PubspecPath -Raw
$PubspecContent = $PubspecContent -replace 'version: \d+\.\d+\.\d+\+\d+', "version: $Version+$(Get-Date -Format 'yyyyMMdd01')"
Set-Content $PubspecPath $PubspecContent

# 更新 home_screen.dart
$HomeScreenPath = "$AppPath\lib\screens\home_screen.dart"
$HomeScreenContent = Get-Content $HomeScreenPath -Raw
$HomeScreenContent = $HomeScreenContent -replace "v\d+\.\d+\.\d+", "v$Version"
Set-Content $HomeScreenPath $HomeScreenContent

Write-Host "✅ 版本号已更新" -ForegroundColor Green

# 清理旧的构建文件
Write-Host "`n🧹 清理旧的构建文件..." -ForegroundColor Yellow
Set-Location $AppPath
& $FlutterPath clean | Out-Null
Write-Host "✅ 清理完成" -ForegroundColor Green

# 构建 APK
Write-Host "`n🔨 构建 APK (Release)..." -ForegroundColor Yellow
$BuildStart = Get-Date
& $FlutterPath build apk --release 2>&1 | ForEach-Object {
    if ($_ -match "Built|Error|FAILURE") {
        Write-Host $_ -ForegroundColor $(if ($_ -match "Built") { "Green" } else { "Red" })
    }
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ 构建失败！" -ForegroundColor Red
    exit 1
}

$BuildEnd = Get-Date
$BuildDuration = ($BuildEnd - $BuildStart).TotalSeconds
Write-Host "✅ 构建完成 (耗时: $([math]::Round($BuildDuration, 1)) 秒)" -ForegroundColor Green

# 复制 APK 到桌面
Write-Host "`n📦 复制 APK 到桌面..." -ForegroundColor Yellow
$Timestamp = Get-Date -Format "yyyyMMdd_HHmm"
$ApkName = "OpenClaw_v${Version}_$Timestamp.apk"
$ApkPath = "$AppPath\build\app\outputs\flutter-apk\app-release.apk"
$DestPath = "$OutputPath\$ApkName"

Copy-Item $ApkPath $DestPath -Force
$ApkSize = [math]::Round((Get-Item $DestPath).Length / 1MB, 2)

Write-Host "✅ APK 已复制到: $DestPath" -ForegroundColor Green
Write-Host "   文件大小: $ApkSize MB" -ForegroundColor Gray

# 生成构建报告
Write-Host "`n📊 构建报告:" -ForegroundColor Cyan
Write-Host "   版本: $Version" -ForegroundColor White
Write-Host "   文件: $ApkName" -ForegroundColor White
Write-Host "   大小: $ApkSize MB" -ForegroundColor White
Write-Host "   耗时: $([math]::Round($BuildDuration, 1)) 秒" -ForegroundColor White
Write-Host "   时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White

# 自动部署（如果指定了 -Deploy 参数）
if ($Deploy) {
    Write-Host "`n📱 检查连接的设备..." -ForegroundColor Yellow
    $Devices = & "D:\Android\platform-tools\adb.exe" devices 2>&1 | Select-String "device$"
    
    if ($Devices) {
        Write-Host "✅ 发现设备，开始安装..." -ForegroundColor Green
        & "D:\Android\platform-tools\adb.exe" install -r $DestPath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ APP 已安装到设备" -ForegroundColor Green
        } else {
            Write-Host "❌ 安装失败" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️ 没有发现连接的设备" -ForegroundColor Yellow
        Write-Host "   请连接设备后手动安装: $DestPath" -ForegroundColor Gray
    }
}

Write-Host "`n🎉 构建完成！" -ForegroundColor Cyan
Write-Host "APK 位置: $DestPath" -ForegroundColor Green
