import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../services/api_service.dart';

class ReportRepository {
  final _api = ApiService.instance;

  Future<({Uint8List bytes, String filename})> _get(
    String path,
    Map<String, dynamic> params,
  ) async {
    final filtered = <String, dynamic>{
      for (final e in params.entries)
        if (e.value != null) e.key: e.value,
    };
    final res = await _api.dio.get<List<int>>(
      path,
      queryParameters: filtered.isEmpty ? null : filtered,
      options: Options(responseType: ResponseType.bytes),
    );
    final disposition = res.headers.value('content-disposition') ?? '';
    final match = RegExp(r"filename\*?=(?:UTF-8'')?([^;]+)").firstMatch(disposition);
    final filename = Uri.decodeComponent(
        match?.group(1)?.trim().replaceAll('"', '') ?? 'report.xlsx');
    return (bytes: Uint8List.fromList(res.data ?? const <int>[]), filename: filename);
  }

  Future<({Uint8List bytes, String filename})> employeeHeadcount({int? deptId}) =>
      _get('/reports/employee-headcount', {'deptId': deptId});

  /// Bước M: NV tham gia bảo hiểm / người phụ thuộc
  Future<({Uint8List bytes, String filename})> insuredEmployees({int? deptId}) =>
      _get('/reports/insured-employees', {'deptId': deptId});

  Future<({Uint8List bytes, String filename})> dependents({int? deptId}) =>
      _get('/reports/dependents', {'deptId': deptId});

  Future<({Uint8List bytes, String filename})> newHires({
    required String from,
    required String to,
    int? deptId,
  }) =>
      _get('/reports/new-hires', {'from': from, 'to': to, 'deptId': deptId});

  Future<({Uint8List bytes, String filename})> resigned({
    required String from,
    required String to,
    int? deptId,
  }) =>
      _get('/reports/resigned', {'from': from, 'to': to, 'deptId': deptId});

  Future<({Uint8List bytes, String filename})> attendanceSummary({
    required int year,
    required int month,
    int? deptId,
  }) =>
      _get('/reports/attendance-summary', {'year': year, 'month': month, 'deptId': deptId});

  Future<({Uint8List bytes, String filename})> overtimeSummary({
    required int year,
    required int month,
    int? deptId,
  }) =>
      _get('/reports/overtime-summary', {'year': year, 'month': month, 'deptId': deptId});

  Future<({Uint8List bytes, String filename})> payrollSummary({
    required int year,
    required int month,
    int? deptId,
  }) =>
      _get('/reports/payroll-summary', {'year': year, 'month': month, 'deptId': deptId});

  Future<({Uint8List bytes, String filename})> leaveBalance({int? deptId}) =>
      _get('/reports/leave-balance', {'deptId': deptId});

  Future<({Uint8List bytes, String filename})> leaveUsage({
    required String from,
    required String to,
    int? deptId,
  }) =>
      _get('/reports/leave-usage', {'from': from, 'to': to, 'deptId': deptId});

  Future<({Uint8List bytes, String filename})> yearlyOverview({
    required int year,
    int? deptId,
  }) =>
      _get('/reports/yearly-overview', {'year': year, 'deptId': deptId});
}
