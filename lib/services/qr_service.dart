import 'dart:typed_data';

import 'qr_service_native.dart'
    if (dart.library.html) 'qr_service_web.dart'
    as impl;

Future<String?> decodeQRFromBytes(Uint8List bytes) =>
    impl.decodeQRFromBytes(bytes);
