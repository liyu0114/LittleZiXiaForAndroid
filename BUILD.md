# OpenClaw Mobile - Build Instructions

## Quick Start

### Step 1: Install Flutter SDK

#### Option A: Automated Installation (Recommended)

```bash
# Run the installation script
C:\Users\Administrator\.openclaw\workspace\mobile-client\install-flutter.cmd
```

#### Option B: Manual Installation

1. Download Flutter SDK:
   https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.3-stable.zip

2. Extract to `C:\flutter`

3. Add to PATH:
   ```
   System Properties → Environment Variables → Path → Add C:\flutter\bin
   ```

4. Verify installation:
   ```bash
   flutter --version
   ```

### Step 2: Install Android Studio

1. Download: https://developer.android.com/studio
2. Install with default settings
3. Open Android Studio
4. Install Android SDK (Tools → SDK Manager)
5. Create virtual device (Tools → Device Manager) or connect physical device

### Step 3: Configure Flutter

```bash
# Check Flutter installation
flutter doctor

# Accept Android licenses
flutter doctor --android-licenses

# Verify everything is OK
flutter doctor
```

### Step 4: Build the App

```bash
# Navigate to project
cd C:\Users\Administrator\.openclaw\workspace\mobile-client\openclaw_app

# Install dependencies
flutter pub get

# Run on emulator/device
flutter run

# Build APK
flutter build apk
```

### Step 5: Install on Phone

1. Transfer `build/app/outputs/flutter-apk/app-release.apk` to phone
2. Enable "Install from unknown sources" in phone settings
3. Open APK and install

## Troubleshooting

### Flutter download failed

Use Chinese mirror:
```bash
# Set environment variables
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# Then download Flutter
```

### Android SDK not found

```bash
# Set ANDROID_HOME
setx ANDROID_HOME "C:\Users\YourName\AppData\Local\Android\Sdk"
setx PATH "%PATH%;%ANDROID_HOME%\platform-tools"
```

### Build fails

```bash
flutter clean
flutter pub get
flutter build apk
```

## Development Workflow

### Hot Reload

When running with `flutter run`, press:
- `r` - Hot reload
- `R` - Hot restart
- `q` - Quit

### Debug Mode

```bash
flutter run --debug
```

### Release Mode

```bash
flutter run --release
```

## Next Steps

After successful build:

1. Configure Gateway URL in app settings
2. Install Tailscale on phone
3. Connect to Tailscale network
4. Start using OpenClaw!
