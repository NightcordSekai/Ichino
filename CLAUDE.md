# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
# Run the app (launches on connected device)
flutter run

# Run analyzer
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Build release artifacts
flutter build apk --release          # Android
flutter build windows --release      # Windows
flutter build macos --release        # macOS
flutter build linux --release        # Linux
flutter build ios --release --no-codesign   # iOS（无证书时只验证可编译）

# Check for outdated dependencies
flutter pub outdated

# Upgrade dependencies
flutter pub upgrade --major-versions
```

## Architecture

This is a Flutter app (Android / iOS / Windows / macOS / Linux) that serves as a QR-code-based
login client for the maimai DX arcade game network.

### Code Layout

```
lib/
├── main.dart                # 入口：main() + MyApp（MaterialApp）
├── pages/
│   ├── login_page.dart      # 登录页（QR 粘贴 / 图片识别）
│   ├── home_page.dart       # 主页骨架（底部导航 + 各 tab）
│   ├── settings_page.dart   # Title Server / 机器参数配置
│   └── ...                  # 各功能页（ticket / best50 / 风险操作等）
├── widgets/
│   ├── cooldown_mixin.dart  # CooldownMixin：登录后冷却倒计时
│   ├── step_progress.dart   # RiskStep + StepProgressCard
│   ├── app_card.dart        # AppCard / SectionTitle / AutoLogoutToggle
│   ├── app_notice.dart      # AppNotice + context.showSnack
│   └── best50_poster.dart   # B50 成绩图
└── services/
    ├── api_service.dart     # Aime 登录 API 客户端
    ├── title_api_service.dart # 游戏服务器传输层（加解密 / 会话 / 各 Api）
    ├── user_all_payload_builder.dart # UpsertUserAll 组装与各补丁
    ├── api_log.dart         # 传输层调试日志（仅 debug）
    └── ...
```

### Key Design Decisions

- **Risk-flow scaffolding is shared**: the feature pages (ticket / unlock music / collectibles /
  travel partner / number patch / map traverse / kaleidx / risk hub) all use `CooldownMixin`,
  `RiskStep`, `StepProgressCard`, `AppCard`, `AppNotice` and `AutoLogoutToggle` instead of
  copy-pasting the same timer / step / banner / card code. Keep new pages on these primitives.
- **QR decoding is native-only**: `services/qr_service.dart` calls the
  `dev.naominet.ichino/qr_scanner` MethodChannel, implemented by Android's `MainActivity` and
  iOS's `SceneDelegate`. Desktop has no handler, so image-based QR scanning is mobile-only.
- **Auth flow**: `ApiService.login()` takes a QR code token (last 64 chars), builds a SHA-256 key
  from `chipID + JST-timestamp + chimeSalt`, and POSTs JSON to the configured Aime URL. A successful
  response has `errorID: 0` and returns `userID` + `token`.
- **Title server transport**: `TitleApiService` derives the URL path from
  `MD5(apiName + salt + obfuscateParam)`, JSON → ZLib → AES-CBC encodes/decodes, and keeps the
  `JSESSIONID` cookie. `getUserPreview` and every other API go through the same `_callApi` helper.
- **Timestamp is JST (UTC+9)** for Aime key derivation, formatted `yyMMddHHmmss`.

### Notable Dependencies

- `http` — API calls
- `crypto` — MD5 URL hash + SHA-256 Aime key
- `pointycastle` / `archive` — AES-CBC + ZLib for the title-server wire format
- `image_picker` — picking QR images from the device gallery
- `shared_preferences` — persisted `TitleServerConfig`
- `share_plus` — exporting the B50 PNG
