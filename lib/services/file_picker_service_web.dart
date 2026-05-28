import 'dart:async';
import 'dart:html';
import 'dart:typed_data';

Future<Uint8List?> pickImageBytes() async {
  final completer = Completer<Uint8List?>();

  final input = FileUploadInputElement()
    ..accept = 'image/*'
    ..click();

  // Detect cancellation: when user closes the file dialog without picking,
  // onChange won't fire, but window.onFocus will when focus returns.
  StreamSubscription<Event>? focusSub;
  focusSub = window.onFocus.listen((_) {
    focusSub?.cancel();
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  });

  input.onChange.listen((_) {
    focusSub?.cancel();

    final file = input.files?.first;
    if (file == null) {
      completer.complete(null);
      return;
    }

    final reader = FileReader();
    reader.onLoad.listen((_) {
      completer.complete(reader.result as Uint8List);
    });

    reader.onError.listen((_) {
      completer.complete(null);
    });

    reader.readAsArrayBuffer(file);
  });

  return completer.future;
}
