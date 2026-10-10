import 'package:dio/dio.dart';

import '../models/labor_contract.dart';
import '../services/api_service.dart';

/// Bước L — /contracts: hợp đồng, phụ lục, cần gia hạn, xuất / nhập Excel.
class ContractRepository {
  final _api = ApiService.instance;

  List<LaborContract> _list(dynamic d) =>
      (d as List).map((e) => LaborContract.fromJson(e as Map<String, dynamic>)).toList();

  LaborContract _one(dynamic d) => LaborContract.fromJson(d as Map<String, dynamic>);

  Future<List<LaborContract>> getAll({int? employeeId}) => _api.get('/contracts', _list,
      queryParams: {if (employeeId != null) 'employeeId': employeeId});

  Future<List<LaborContract>> expiring({int? days}) =>
      _api.get('/contracts/expiring', _list, queryParams: {if (days != null) 'days': days});

  Future<LaborContract> create(Map<String, dynamic> body) => _api.post('/contracts', _one, body);

  Future<LaborContract> update(int id, Map<String, dynamic> body) => _api.put('/contracts/$id', _one, body);

  Future<LaborContract> activate(int id) => _api.post('/contracts/$id/activate', _one, const {});

  Future<LaborContract> terminate(int id, String terminationDate, String? reason) =>
      _api.post('/contracts/$id/terminate', _one, {'terminationDate': terminationDate, 'reason': reason});

  Future<void> delete(int id) => _api.delete('/contracts/$id');

  Future<LaborContract> addAppendix(int contractId, Map<String, dynamic> body) =>
      _api.post('/contracts/$contractId/appendices', _one, body);

  Future<LaborContract> updateAppendix(int appendixId, Map<String, dynamic> body) =>
      _api.put('/contracts/appendices/$appendixId', _one, body);

  Future<void> deleteAppendix(int appendixId) => _api.delete('/contracts/appendices/$appendixId');

  Future<Response<List<int>>> export() => _api.dio.get<List<int>>(
        '/contracts/export',
        options: Options(responseType: ResponseType.bytes),
      );

  Future<List<dynamic>> previewImport(List<int> bytes, String filename) async {
    final r = await _api.dio.post('/contracts/preview-import',
        data: FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: filename)}));
    return r.data as List<dynamic>;
  }

  Future<void> importExcel(List<int> bytes, String filename) => _api.dio.post('/contracts/import',
      data: FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: filename)}));
}
