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
