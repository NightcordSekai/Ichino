import 'dart:typed_data';

import 'file_picker_service_native.dart'
    if (dart.library.html) 'file_picker_service_web.dart'
    as impl;

Future<Uint8List?> pickImageBytes() => impl.pickImageBytes();
