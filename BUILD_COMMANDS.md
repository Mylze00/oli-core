# OLI-CORE Flutter Build & Test Commands

## 1. Local Testing (Web/Desktop)

### Test on Web (Chrome)
```bash
cd ~/oli-core/oli_app
flutter run -d chrome
```

### Test on Linux Desktop
```bash
# Install missing dependencies first
sudo apt-get install libgstreamer1.0-0 libgstreamer-plugins-base1.0-0

cd ~/oli-core/oli_app
flutter run -d linux
```

## 2. Build Web (Production)

```bash
cd ~/oli-core/oli_app
flutter build web --release
```

Output: `build/web/`

Deploy to Vercel/Firebase hosting:
```bash
# Vercel
vercel --prod

# Firebase
firebase deploy --only hosting
```

## 3. Build APK (Android - Production)

### Prerequisites
- Android SDK installed
- Keystore configured
- API key setup

### Build APK
```bash
cd ~/oli-core/oli_app
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Build App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

## 4. Quick Analysis & Validation

### Check for compile errors
```bash
flutter analyze lib/features/checkout/screens/checkout_page.dart
```

### Full project analysis
```bash
flutter analyze
```

## 5. Fixed Issues (Current Session)

- ✅ `checkout_page.dart`: Fixed User type import, removed unused imports
- ✅ `checkout_page.dart`: Replaced deprecated `withOpacity()` with `withValues(alpha:)`
- ✅ `web/index.html`: Removed deprecated `window.flutterConfiguration` for new web API

## Environment Notes

- Flutter: `/mnt/c/flutter/bin/flutter`
- Dart: `/mnt/c/flutter/bin/dart`
- WSL: Ubuntu 24.04
- Fixed line endings in Flutter scripts (CRLF → LF)
