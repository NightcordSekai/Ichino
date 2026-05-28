import 'package:flutter/services.dart';

const _channel = MethodChannel('com.ichino/qr_scanner');

Future<String?> decodeQRFromBytes(Uint8List bytes) async {
  try {
    final result = await _channel.invokeMethod<String>('decodeQRFromBytes', bytes);
    return result;
  } on PlatformException {
    return null;
  }
}
