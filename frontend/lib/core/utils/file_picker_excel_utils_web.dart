import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<({Uint8List bytes, String filename})?> pickExcelFile() async {
  final completer = Completer<({Uint8List bytes, String filename})?>();

  final input = html.FileUploadInputElement()
    ..accept = '.xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

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

  input.click();
  return completer.future;
}
