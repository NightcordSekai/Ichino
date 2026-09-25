import 'dart:io';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

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
    // Linux 与 Windows 10 RS5 之前不支持分享文件，文件已落盘，返回路径即可。
  }

  return file.path;
}
