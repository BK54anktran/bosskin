import '../models/dependent.dart';
import '../services/api_service.dart';

/// Bước M — /dependents: người phụ thuộc của nhân viên.
class DependentRepository {
  final _api = ApiService.instance;

  List<Dependent> _list(dynamic d) =>
      (d as List).map((e) => Dependent.fromJson(e as Map<String, dynamic>)).toList();

  Dependent _one(dynamic d) => Dependent.fromJson(d as Map<String, dynamic>);

  Future<List<Dependent>> getAll(int employeeId) =>
      _api.get('/dependents', _list, queryParams: {'employeeId': employeeId});

  Future<List<Dependent>> getSelf() => _api.get('/dependents/self', _list);

  Future<Dependent> create(Map<String, dynamic> body) => _api.post('/dependents', _one, body);

  Future<Dependent> update(int id, Map<String, dynamic> body) => _api.put('/dependents/$id', _one, body);

  Future<void> delete(int id) => _api.delete('/dependents/$id');
}
