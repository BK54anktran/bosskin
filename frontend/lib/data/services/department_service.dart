import 'package:dio/dio.dart';
import '../../core/config/server_config.dart';
import '../../core/localization/language_service.dart';
import '../models/department_model.dart';
import 'auth_service.dart';

class DepartmentService {
  static final DepartmentService instance = DepartmentService._();
  DepartmentService._();

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
}
