# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
# Run the app (launches on connected device or browser)
flutter run

# Run specifically for web (primary target)
flutter run -d chrome

# Run analyzer
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Build for web
flutter build web

# Check for outdated dependencies
flutter pub outdated

# Upgrade dependencies
flutter pub upgrade --major-versions
```

## Architecture

This is a Flutter app (targeting mobile native) that serves as a QR-code-based login client for the maimai DX arcade game network.

### Code Layout

```
lib/
├── main.dart                # App entry point, LoginPage widget (the entire UI)
└── services/
    ├── api_service.dart     # API client for game server auth
    ├── qr_service.dart      # Platform-agnostic QR decode interface (conditional import)
    ├── qr_service_native.dart  # Native stub — QR decode is NOT implemented on mobile/desktop
    └── qr_service_web.dart  # Web QR decode via jsQR (loaded in web/index.html via CDN)
```

### Key Design Decisions

- **Single-widget app**: The entire app is currently one `LoginPage` widget in `main.dart`. There is no routing — the login result shows an `AlertDialog`.
- **Conditional imports for platform code**: `qr_service.dart` uses the `if (dart.library.html)` syntax to import `qr_service_web.dart` on web and `qr_service_native.dart` everywhere else. Native QR scanning returns `null` (not implemented).
- **Web is the primary target**: jsQR is loaded via CDN `<script>` tag in `web/index.html`. The web QR decoder draws the image onto a `<canvas>`, extracts `ImageData`, and calls `jsQR()` via `dart:js`.
- **Auth flow**: `ApiService.login()` takes a QR code token (last 64 chars), builds a SHA-256 key from `chipID + JST-timestamp + chimeSalt`, and POSTs JSON to `http://ai.sys-allnet.cn/wc_aime/api/get_data`. A successful response has `errorID: 0` and returns `userID` + `token`.
- **Timestamp is JST (UTC+9)**: The API key derivation uses Japan Standard Time, formatted as `yyMMddHHmmss`.

### Notable Dependencies

- `http` — API calls
- `crypto` — SHA-256 for API key derivation
- `image_picker` — picking QR images from the device gallery
- `google_fonts` — custom fonts (currently unused in code)
