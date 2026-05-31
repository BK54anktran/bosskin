import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../services/api_service.dart';

class UploadRepository {
  final _api = ApiService.instance;

  Future<String> uploadImage({
    required Uint8List bytes,
    required String filename,
    String folder = 'images',
  }) async {
    return _upload(
      endpoint: '/upload/image',
      bytes: bytes,
      filename: filename,
      folder: folder,
    );
  }

  Future<String> uploadDocument({
    required Uint8List bytes,
    required String filename,
    String folder = 'documents',
  }) async {
    return _upload(
      endpoint: '/upload/document',
      bytes: bytes,
      filename: filename,
      folder: folder,
    );
  }

  Future<String> _upload({
    required String endpoint,
    required Uint8List bytes,
    required String filename,
    required String folder,
  }) async {
    final safeFilename = filename.isNotEmpty ? filename : 'file.jpg';
    final contentType = _detectContentType(safeFilename);

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: safeFilename,
        contentType: MediaType.parse(contentType),
      ),
      'folder': folder,
    });

    final res = await _api.dio.post(
      endpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return res.data['url'] as String;
  }

  String _detectContentType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    return switch (ext) {
      'png'  => 'image/png',
      'webp' => 'image/webp',
      'gif'  => 'image/gif',
      'pdf'  => 'application/pdf',
      'doc'  => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls'  => 'application/vnd.ms-excel',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      _      => 'image/jpeg',
    };
  }
}
