import '../services/api_service.dart';

class PositionModel {
  final int id;
  final String name;
  final String code;
  final int departmentId;
  final String departmentName;
  final String? description;

  const PositionModel({
    required this.id,
    required this.name,
    required this.code,
    required this.departmentId,
    required this.departmentName,
    this.description,
  });

  factory PositionModel.fromJson(Map<String, dynamic> j) => PositionModel(
        id: j['id'],
        name: j['name'],
        code: j['code'],
        departmentId: j['departmentId'],
        departmentName: j['departmentName'] ?? '',
        description: j['description'],
      );
}

class PositionService {
  static final PositionService instance = PositionService._();
  PositionService._();

  final _api = ApiService.instance;

  Future<List<PositionModel>> getAll() async {
    return _api.get(
      '/positions',
      (data) => (data as List).map((e) => PositionModel.fromJson(e)).toList(),
    );
  }

  Future<List<PositionModel>> getByDepartment(int departmentId) async {
    return _api.get(
      '/positions',
      (data) => (data as List).map((e) => PositionModel.fromJson(e)).toList(),
      queryParams: {'departmentId': departmentId},
    );
  }

  Future<PositionModel> create(Map<String, dynamic> data) async {
    return _api.post('/positions', (data) => PositionModel.fromJson(data), data);
  }

  Future<PositionModel> update(int id, Map<String, dynamic> data) async {
    return _api.put('/positions/$id', (data) => PositionModel.fromJson(data), data);
  }

  Future<void> delete(int id) => _api.delete('/positions/$id');
}
