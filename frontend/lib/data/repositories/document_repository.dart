import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../core/config/server_config.dart';
import '../models/employee_document.dart';
import '../services/api_service.dart';

/// Bước N — /document-types, /employee-documents: tài liệu nhân sự.
class DocumentRepository {
  final _api = ApiService.instance;

  List<EmployeeDocument> _list(dynamic d) =>
      (d as List).map((e) => EmployeeDocument.fromJson(e as Map<String, dynamic>)).toList();

  EmployeeDocument _one(dynamic d) => EmployeeDocument.fromJson(d as Map<String, dynamic>);

  DocumentLink _link(dynamic d) => DocumentLink.fromJson(d as Map<String, dynamic>);

  // ── Loại tài liệu ──
  Future<List<DocumentType>> getTypes() => _api.get('/document-types',
      (d) => (d as List).map((e) => DocumentType.fromJson(e as Map<String, dynamic>)).toList());

  Future<void> createType(Map<String, dynamic> body) => _api.post('/document-types', (_) {}, body);

  Future<void> updateType(int id, Map<String, dynamic> body) => _api.put('/document-types/$id', (_) {}, body);

  Future<void> deleteType(int id) => _api.delete('/document-types/$id');

  // ── Tài liệu (HR) ──
  Future<List<EmployeeDocument>> getAll(int employeeId) =>
      _api.get('/employee-documents', _list, queryParams: {'employeeId': employeeId});

  Future<List<EmployeeDocument>> getPending() => _api.get('/employee-documents/pending', _list);

  Future<List<EmployeeDocument>> getExpiring({int? days}) =>
      _api.get('/employee-documents/expiring', _list, queryParams: {if (days != null) 'days': days});

  Future<List<MissingDocuments>> getMissing() => _api.get('/employee-documents/missing',
      (d) => (d as List).map((e) => MissingDocuments.fromJson(e as Map<String, dynamic>)).toList());

  Future<EmployeeDocument> upload(Map<String, dynamic> fields, Uint8List bytes, String filename) =>
      _upload('/employee-documents', fields, bytes, filename);

  Future<EmployeeDocument> update(int id, Map<String, dynamic> body) =>
      _api.put('/employee-documents/$id', _one, body);

  Future<void> delete(int id) => _api.delete('/employee-documents/$id');

  Future<EmployeeDocument> approve(int id, String? note) =>
      _api.post('/employee-documents/$id/approve', _one, {'note': note});

  Future<EmployeeDocument> reject(int id, String? note) =>
      _api.post('/employee-documents/$id/reject', _one, {'note': note});

  Future<DocumentLink> getLink(int id) => _api.get('/employee-documents/$id/link', _link);

  // ── Tự phục vụ ──
  Future<List<EmployeeDocument>> getSelf() => _api.get('/employee-documents/self', _list);

  Future<EmployeeDocument> uploadSelf(Map<String, dynamic> fields, Uint8List bytes, String filename) =>
      _upload('/employee-documents/self', fields, bytes, filename);

  Future<DocumentLink> getSelfLink(int id) => _api.get('/employee-documents/self/$id/link', _link);

  Future<void> deleteSelf(int id) => _api.delete('/employee-documents/self/$id');

  Future<EmployeeDocument> _upload(String path, Map<String, dynamic> fields, Uint8List bytes, String filename) async {
    final form = FormData.fromMap({
      ...Map.fromEntries(fields.entries.where((e) => e.value != null && e.value.toString().isNotEmpty)),
      'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: MediaType.parse(contentTypeOf(filename))),
    });
    final res = await _api.dio.post(path, data: form);
    return _one(res.data);
  }

  /// Tải nội dung file theo link ký tạm (không gửi token: quyền nằm trong chữ ký của link).
  Future<Uint8List> fetchLink(DocumentLink link) async {
    final url = link.url.startsWith('/') ? '${ServerConfig.host}${link.url}' : link.url;
    final res = await Dio().get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
    return Uint8List.fromList(res.data!);
  }

  static String contentTypeOf(String filename) {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'application/octet-stream',
    };
  }
}
