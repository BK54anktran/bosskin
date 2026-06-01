import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/employee.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../../core/config/server_config.dart';
import '../../core/localization/language_service.dart';


class EmployeeRepository {
  final _api = ApiService.instance;

  Dio get _dio {
    final token = AuthService.instance.currentUser?.token ?? '';
    return Dio(BaseOptions(
      baseUrl: ServerConfig.baseUrl,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept-Language': LanguageService.instance.locale.toLanguageTag(),
      },
    ));
  }

  Future<({List<Employee> items, int total})> getAll({
    int page = 0,
    int size = 20,
    String? search,
    int? departmentId,
    EmployeeStatus? status,
  }) async {
    final params = {
      'page': page,
      'size': size,
      if (search != null) 'search': search,
      if (departmentId != null) 'departmentId': departmentId,
      if (status != null) 'status': status.name.toUpperCase(),
    };
    return _api.get(
      '/employees',
      (data) => (
        items: (data['content'] as List)
            .map((e) => Employee.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (data['totalElements'] as num?)?.toInt() ?? 0,
      ),
      queryParams: params,
    );
  }

  Future<Employee> getById(int id) async {
    return _api.get(
      '/employees/$id',
      (data) => Employee.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Employee> create(Map<String, dynamic> data) async {
    return _api.post(
      '/employees',
      (data) => Employee.fromJson(data as Map<String, dynamic>),
      data,
    );
  }

  Future<Employee> update(int id, Map<String, dynamic> data) async {
    return _api.put(
      '/employees/$id',
      (data) => Employee.fromJson(data as Map<String, dynamic>),
      data,
    );
  }

  Future<void> delete(int id) => _api.delete('/employees/$id');

  Future<Map<String, dynamic>> syncMissingUsers(String initialPassword) async {
    return _api.post(
      '/users/sync-from-employees',
      (data) => Map<String, dynamic>.from(data as Map),
      {'initialPassword': initialPassword},
    );
  }

  Future<({Uint8List bytes, String filename})> exportExcel() async {
    final res = await _dio.get<List<int>>(
      '/employees/export',
      options: Options(responseType: ResponseType.bytes),
    );
    final disposition = res.headers.value('content-disposition') ?? '';
    final match = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
    final filename = match?.group(1) ?? 'danh_sach_nhan_vien.xlsx';
    return (bytes: Uint8List.fromList(res.data!), filename: filename);
  }

  Future<List<EmployeeImportDiff>> previewImport(
      Uint8List bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post('/employees/preview-import', data: formData);
    return (res.data as List)
        .map((e) => EmployeeImportDiff.fromJson(e))
        .toList();
  }

  Future<void> importExcel(Uint8List bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    await _dio.post('/employees/import', data: formData);
  }
}
