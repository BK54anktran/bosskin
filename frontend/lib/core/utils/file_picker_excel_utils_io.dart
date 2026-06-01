import 'dart:typed_data';

Future<({Uint8List bytes, String filename})?> pickExcelFile() async {
  // Mobile/desktop: không hỗ trợ file picker không cần thêm package
  // Chỉ dùng trên web (file_picker_excel_utils_web.dart)
  return null;
}
