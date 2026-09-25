import 'package:flutter/services.dart';

/// QR 解码走平台原生实现：Android 的 `MainActivity` 与 iOS 的 `SceneDelegate`
/// 注册了这个 MethodChannel。
///
/// 桌面平台（Windows/macOS/Linux）没有对应 handler，调用会抛
/// `MissingPluginException`，由 `main.dart` 的登录页捕获后提示解析失败。
const _channel = MethodChannel('dev.naominet.ichino/qr_scanner');

Future<String?> decodeQRFromBytes(Uint8List bytes) async {
  try {
    final result = await _channel.invokeMethod<String>('decodeQRFromBytes', bytes);
    return result;
  } on PlatformException {
    return null;
  }
}
