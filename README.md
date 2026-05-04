# OpenClaw Mobile Client

A Flutter-based mobile client for OpenClaw Gateway.

## Features

✅ **Gateway Connection Management**
- WebSocket connection to OpenClaw Gateway
- Auto-reconnect on disconnect
- Authentication with token
- Real-time status display

✅ **Real-Time Status Visibility** (解决飞书的问题)
- Visual connection status indicator
- Active task display with progress
- Task cancellation support
- Message history

✅ **Flexible Configuration**
- Configurable Gateway URL
- Configurable authentication token
- All sensitive info stored locally

✅ **Tailscale Integration** (方案 A)
- Use Tailscale as independent app
- Detailed setup instructions provided
- No complex VPN permission handling

## Product Forms

### 1. SDK (`packages/openclaw_sdk`)
Core functionality library in pure Dart.
```dart
import 'package:openclaw_sdk/openclaw_sdk.dart';

final client = GatewayClient(
  config: OpenClawConfig(
    gatewayUrl: 'http://100.80.206.8:18789',
    token: 'your-token',
  ),
);

await client.connect();
await client.sendMessage('Hello OpenClaw!');
```

### 2. Plugin (`packages/openclaw_plugin`)
Flutter plugin with native integrations (coming soon).

### 3. App (`packages/openclaw_app`)
Complete mobile application ready to use.

## Getting Started

### Prerequisites

1. **Install Flutter SDK**
   ```bash
   # Windows
   https://docs.flutter.dev/get-started/install/windows

   # Add to PATH
   C:\flutter\bin
   ```

2. **Install Android Studio**
   - Download: https://developer.android.com/studio
   - Install Android SDK
   - Configure emulator or connect physical device

3. **Install Tailscale** (on your phone)
   - See: `docs/TAILSCALE_SETUP.md`

### Build & Run

```bash
# Navigate to app directory
cd packages/openclaw_app

# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Build APK
flutter build apk

# Build for release
flutter build apk --release
```

## Project Structure

```
openclaw-mobile/
├── packages/
│   ├── openclaw_sdk/          # Core SDK
│   │   ├── lib/
│   │   │   ├── src/
│   │   │   │   ├── gateway_client.dart
│   │   │   │   ├── models.dart
│   │   │   │   ├── protocol.dart
│   │   │   │   ├── config.dart
│   │   │   │   └── exceptions.dart
│   │   │   └── openclaw_sdk.dart
│   │   └── pubspec.yaml
│   │
│   ├── openclaw_plugin/       # Native Plugin (TBD)
│   │
│   └── openclaw_app/          # Complete App
│       ├── lib/
│       │   ├── main.dart
│       │   ├── providers/
│       │   ├── screens/
│       │   ├── widgets/
│       │   └── theme/
│       ├── android/
│       ├── ios/
│       └── pubspec.yaml
│
├── docs/
│   └── TAILSCALE_SETUP.md     # Tailscale Setup Guide
│
└── README.md
```

## Configuration

### Gateway Settings

In the app, go to Settings and configure:

- **Gateway URL**: `http://100.80.206.8:18789` (your Tailscale IP)
- **Token**: Your OpenClaw Gateway token

### Token Location

On Windows, find your token in:
```
C:\Users\Administrator\.openclaw\gateway.cmd
```

Look for `OPENCLAW_GATEWAY_TOKEN=...`

## Solving the Feishu Problem

### What was wrong with Feishu?

- ❌ No visible connection status
- ❌ Don't know if Gateway is working
- ❌ No task progress indication
- ❌ Silent failures

### How OpenClaw App solves it

- ✅ **Real-time status**: Green = connected, Red = error
- ✅ **Active tasks**: See what's running with progress bars
- ✅ **Task visibility**: Know when OpenClaw is working
- ✅ **Instant feedback**: Messages appear immediately
- ✅ **Error handling**: Clear error messages

## Architecture

### State Management
- Provider for global state
- Stream-based real-time updates

### Communication
- WebSocket for Gateway connection
- JSON-RPC protocol
- Event-based notifications

### Data Flow
```
User Input → AppState → GatewayClient → WebSocket → Gateway
                ↑                                        ↓
            UI Update ← Stream ← Notification ← Task/Message
```

## Development

### Run Tests
```bash
cd packages/openclaw_sdk
flutter test
```

### Generate Code
```bash
flutter pub run build_runner build
```

### Lint
```bash
flutter analyze
```

## Deployment

### Android APK

```bash
# Debug
flutter build apk

# Release
flutter build apk --release

# Output
build/app/outputs/flutter-apk/app-release.apk
```

### Install on Device

1. Transfer APK to phone
2. Enable "Install from unknown sources"
3. Open APK and install

## Troubleshooting

### Can't connect to Gateway

1. Check Tailscale is connected on phone
2. Verify Gateway URL uses Tailscale IP (100.x.x.x)
3. Check Gateway is running on Windows
4. Verify firewall allows port 18789

### Flutter build errors

```bash
flutter clean
flutter pub get
flutter build apk
```

### Android SDK not found

```bash
flutter doctor --android-licenses
flutter doctor
```

## Next Steps

1. ✅ SDK implementation
2. ✅ App UI
3. ⏳ Testing on real device
4. ⏳ Plugin implementation (optional)
5. ⏳ iOS version (on Mac)

## License

MIT

## Contributing

Contributions welcome! Please read the contributing guidelines first.

## Support

For issues and feature requests, please use the GitHub issue tracker.
