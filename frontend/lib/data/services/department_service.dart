import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../core/config/server_config.dart';
import '../../core/localization/language_service.dart';
import '../models/department_model.dart';
import 'auth_service.dart';

class DepartmentService {
  static final DepartmentService instance = DepartmentService._();
  DepartmentService._();

  Dio get _dio {
    final auth = AuthService.instance;
    final token = (auth.impersonatingUser ?? auth.currentUser)?.token ?? '';
    return Dio(BaseOptions(
      baseUrl: ServerConfig.baseUrl,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept-Language': LanguageService.instance.locale.toLanguageTag(),
      },
    ));
  }

  Future<List<DepartmentNode>> getTree() async {
    final res = await _dio.get('/departments');
    return (res.data as List).map((e) => DepartmentNode.fromJson(e)).toList();
  }

  Future<List<DepartmentFlat>> getFlat({String permission = 'DEPARTMENT_VIEW'}) async {
    final res = await _dio.get('/departments/flat', queryParameters: {'permission': permission});
    return (res.data as List).map((e) => DepartmentFlat.fromJson(e)).toList();
  }

  Future<DepartmentNode> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/departments', data: data);
    return DepartmentNode.fromJson(res.data);
  }

  Future<DepartmentNode> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/departments/$id', data: data);
    return DepartmentNode.fromJson(res.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/departments/$id');
  }

  Future<({Uint8List bytes, String filename})> exportExcel() async {
    final res = await _dio.get<List<int>>(
      '/departments/export',
      options: Options(responseType: ResponseType.bytes),
    );
    final disposition = res.headers.value('content-disposition') ?? '';
    final match = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
    final filename = match?.group(1) ?? 'danh_sach_phong_ban.xlsx';
    return (bytes: Uint8List.fromList(res.data!), filename: filename);
  }

  Future<List<DepartmentImportDiff>> previewImport(Uint8List bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post('/departments/preview-import', data: formData);
    return (res.data as List).map((e) => DepartmentImportDiff.fromJson(e)).toList();
  }

  Future<void> importExcel(Uint8List bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    await _dio.post('/departments/import', data: formData);
  }

  Future<List<PositionImportDiff>> previewImportPositions(
      Uint8List bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res =
        await _dio.post('/departments/positions/preview-import', data: formData);
    return (res.data as List)
        .map((e) => PositionImportDiff.fromJson(e))
        .toList();
  }

  Future<void> importPositions(Uint8List bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    await _dio.post('/departments/positions/import', data: formData);
  }
}
