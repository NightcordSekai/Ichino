import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// 从相册选取一张图片并读出字节，供 QR 解码用。
Future<Uint8List?> pickImageBytes() async {
  final picker = ImagePicker();
  final file = await picker.pickImage(source: ImageSource.gallery);
  if (file == null) return null;
  return await file.readAsBytes();
}
