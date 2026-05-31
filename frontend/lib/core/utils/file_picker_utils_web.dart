import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<({Uint8List bytes, String filename})?> pickImageFile() async {
  final completer = Completer<({Uint8List bytes, String filename})?>();

  final input = html.FileUploadInputElement()
    ..accept = 'image/jpeg,image/png,image/webp,image/gif';

  input.onChange.listen((event) async {
    final file = input.files?.first;
    if (file == null) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoadEnd.listen((_) {
      try {
        final result = reader.result;
        // dart:html trả về ByteBuffer trên web
        final bytes = result is ByteBuffer
            ? Uint8List.view(result)
            : Uint8List.fromList(result as List<int>);
        completer.complete((bytes: bytes, filename: file.name));
      } catch (e) {
        completer.completeError(e);
      }
    });
    reader.onError.listen((_) => completer.complete(null));
  });

  // Click phải sau khi gắn listener
  input.click();

  return completer.future;
}
