# Ichino

基于 QR Code 登录的 maimai DX 国服第三方客户端，Flutter 实现，覆盖
Android / iOS / Web / Windows / macOS / Linux。

包名 `ichino`，应用标识 `dev.naominet.ichino`。

> ⚠️ 「风险」页里的功能会向服务器发送伪造的 `UpsertUserAllApi` 数据包，属于高危操作，
> 可能封号。请自行评估风险。

## 功能

| 入口 | 说明 |
| --- | --- |
| 主页 | Aime 登录（QR / 令牌）、Rating 详情、入坑信息、游玩统计、状态 |
| 票据 | 功能票查询与使用 |
| B50 | Best 50 成绩图，可导出 PNG（移植自 Empurple 的 `Best50ImageRenderer`） |
| 风险 | 歌曲解锁、收藏品获取、旅行伙伴发放与编组 |
| 设置 | Title Server / Auth Server / 机器参数，支持配置导入导出 |

## 开发

```bash
flutter pub get
flutter run                      # 默认设备
flutter run -d chrome            # Web
flutter analyze                  # 需保持 0 error/warning
flutter test
```

构建产物：

```bash
flutter build apk --release          # Android
flutter build windows --release      # Windows（产物为 ichino.exe）
flutter build macos --release        # macOS
flutter build linux --release        # Linux
flutter build web --release          # Web
flutter build ios --release --no-codesign   # iOS（无证书时只验证可编译）
```

## 目录结构

```
lib/
├── main.dart            # 入口 + 登录页
├── config/              # 字符串、响应式布局、Title Server 配置
├── models/              # API 数据模型（UserData / UserPreview / UserRating / UserCharacter）
├── pages/               # 各功能页面
├── services/            # 传输层、乐曲元数据、导出、RA 计算
└── widgets/             # 可复用视觉组件（B50 海报）
```

平台相关代码用条件导入分离，形如 `xxx_service.dart` + `xxx_service_native.dart`
+ `xxx_service_web.dart`（见 `qr_service`、`file_picker_service`、
`png_export_service`、`music_data_cache`）。

## 关键实现说明

- **传输层**：`TitleApiService` 负责 `MD5(apiName + salt + obfuscateParam)` 生成 URL 路径、
  JSON → ZLib → AES-CBC 编解码、`Set-Cookie` 会话维持。时间戳用 JST（UTC+9）。
- **B50 成绩图**：底图 `assets/b50/base.png`（1762×1850）之上按固定像素坐标叠加头像、
  昵称、50 张卡片与页脚；卡片 300×100、每行 5 张，BEST35 从 y=350 起、BEST15 固定从
  y=1250 起。RA 与评级由 `RatingCalculator` 计算，曲名与定数取自 diving-fish 的
  `music_data`。导出走 `RepaintBoundary`，预览缩放不影响导出分辨率。
- **旅行伙伴 ≠ 搭档**：旅行伙伴是 `ItemKind.Character = 9`，走
  `upsertUserAll.userCharacterList`（`{characterId, level, awakening, useCount}`）；
  搭档是 `ItemKind.Partner = 10`，走 `userItemList`。出战编组是
  `UserDetail.charaSlot`（`int[5]`，槽 0 为队长）。

## 构建环境注意事项

以下问题在本仓库已确认，改动依赖或升级 Flutter 时请留意：

1. **`path_provider_android` 必须钉在 2.3.0 以下**（见 `pubspec.yaml` 的
   `dependency_overrides`）。2.3.x 起它依赖 `jni`，而 `jni` 把 `windows`/`linux`
   也声明成 `ffiPlugin`，只要它出现在依赖树里，桌面构建就会去链接 `jvm.lib` 并失败。
   `share_plus` 间接依赖 `path_provider`，所以不能靠去掉直接依赖解决。
2. **命令行构建请显式指定 JDK**。Android Studio 常驻的 Gradle daemon 用它自带的 JBR，
   而 JBR 不含 `jlink.exe`，会导致
   `:flutter_plugin_android_lifecycle:compileReleaseJavaWithJavac` 失败。
   在 `~/.gradle/gradle.properties` 里设置
   `org.gradle.java.home=<一个完整 JDK>` 即可。判据：`--no-daemon` 能过而带 daemon 不过。
3. **Release APK 目前使用 debug 签名**（`android/app/build.gradle.kts` 的
   `signingConfig`），产物可直接安装，但不是正式发布签名。

## CI

`.github/workflows/build.yml` 在 push / PR / 手动触发时执行：

- `checks`：`flutter analyze` + `flutter test`，作为其余作业的前置门槛
- `android`：`app-release.apk`
- `windows`：`ichino-windows-x64.zip`（含 `ichino.exe` 及运行所需 dll/assets）
- `ios`：`ichino-ios-unsigned.ipa`

产物以 artifact 形式上传。**注意 iOS 包是未签名的**：GitHub 托管的 macOS runner 没有
证书与描述文件，该 ipa 只能用于验证编译，无法直接安装到设备。要出可安装的 ipa，需要在
仓库 Secrets 中配置签名证书并改用 `--codesign`。

## 致谢

- 图标与封面资源：assets2.lxns.net
- 乐曲定数与曲名：diving-fish
- B50 版面与本作 UI：chuxuehaocai
