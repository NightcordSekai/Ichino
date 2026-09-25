import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<String?> exportPng(Uint8List bytes, String fileName) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(bytes, name: fileName, mimeType: 'image/png'),
      ],
      fileNameOverrides: [fileName],
    ),
  );
  return null;
}
