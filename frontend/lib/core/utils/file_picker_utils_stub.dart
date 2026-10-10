import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

Future<({Uint8List bytes, String filename})?> pickImageFile() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );
  if (picked == null) return null;
  final bytes = await picked.readAsBytes();
  final filename = picked.name.isNotEmpty ? picked.name : 'avatar.jpg';
  return (bytes: bytes, filename: filename);
}

/// Bước N — chọn file tài liệu nhân sự. Bản mobile/desktop chỉ chọn được ảnh (chưa có file picker chung).
Future<({Uint8List bytes, String filename})?> pickDocumentFile() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
  if (picked == null) return null;
  final bytes = await picked.readAsBytes();
  return (bytes: bytes, filename: picked.name.isNotEmpty ? picked.name : 'document.jpg');
}
