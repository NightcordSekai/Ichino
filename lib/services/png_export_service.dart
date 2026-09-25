import 'dart:typed_data';

import 'png_export_service_native.dart'
    if (dart.library.html) 'png_export_service_web.dart' as impl;

/// 导出一张 PNG：原生平台落临时盘并拉起系统分享，Web 走下载或 Web Share API。
///
/// 返回原生平台上的落盘路径（用于分享能力缺失时提示用户），Web 返回 null。
Future<String?> exportPng(Uint8List bytes, String fileName) =>
    impl.exportPng(bytes, fileName);
