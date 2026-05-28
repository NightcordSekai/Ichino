import 'dart:async';
import 'dart:html';
import 'dart:js' as js;
import 'dart:typed_data';

Future<String?> decodeQRFromBytes(Uint8List bytes) async {
  final completer = Completer<String?>();

  final blob = Blob([bytes]);
  final url = Url.createObjectUrlFromBlob(blob);

  final img = ImageElement()..src = url;

  img.onLoad.listen((_) {
    try {
      final canvas = CanvasElement(
        width: img.naturalWidth,
        height: img.naturalHeight,
      );
      final ctx = canvas.context2D;
      ctx.drawImage(img, 0, 0);
      final imageData = ctx.getImageData(
        0,
        0,
        img.naturalWidth,
        img.naturalHeight,
      );

      if (!js.context.hasProperty('jsQR')) {
        Url.revokeObjectUrl(url);
        completer.completeError('jsQR library not loaded');
        return;
      }

      final result = js.context.callMethod('jsQR', [
        imageData.data,
        imageData.width,
        imageData.height,
      ]);

      Url.revokeObjectUrl(url);

      if (result != null) {
        completer.complete(result['data'] as String?);
      } else {
        completer.complete(null);
      }
    } catch (e) {
      Url.revokeObjectUrl(url);
      completer.completeError(e);
    }
  });

  img.onError.listen((_) {
    Url.revokeObjectUrl(url);
    completer.complete(null);
  });

  return completer.future;
}
