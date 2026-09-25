import 'dart:io';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// 导出一张 PNG：先落临时盘，再拉起系统分享面板。
///
/// 返回落盘路径，供分享能力缺失时提示用户。Linux 与 Windows 10 RS5 之前
/// 的 share_plus 不支持分享文件，会抛 UnimplementedError，此时文件仍在盘上。
Future<String?> exportPng(Uint8List bytes, String fileName) async {
  final file = File('${Directory.systemTemp.path}/$fileName');
  await file.writeAsBytes(bytes);

  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: fileName, mimeType: 'image/png')],
        fileNameOverrides: [fileName],
      ),
    );
  } on UnimplementedError {
    // 该平台不支持分享文件，文件已落盘，返回路径即可。
  }

  return file.path;
}
