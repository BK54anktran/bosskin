import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/payroll.dart';
import '../services/api_service.dart';

class PayrollPage {
  final List<Payroll> content;
  final int totalElements;
  final int totalPages;
  final int page;

  const PayrollPage({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.page,
  });

  factory PayrollPage.fromJson(Map<String, dynamic> j) => PayrollPage(
        content: (j['content'] as List)
            .map((e) => Payroll.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalElements: (j['totalElements'] as num).toInt(),
        totalPages: (j['totalPages'] as num).toInt(),
        page: (j['number'] as num).toInt(),
      );
}

class PayrollRepository {
  final _api = ApiService.instance;

  Future<PayrollPage> getByMonth(
    int year,
    int month, {
    int? departmentId,
    String? status,
    int page = 0,
    int size = 50,
  }) async {
    final params = <String, dynamic>{
      'year': year,
      'month': month,
      'page': page,
      'size': size,
      if (departmentId != null) 'departmentId': departmentId,
      if (status != null) 'status': status,
    };
    return _api.get(
      '/payrolls',
      (data) => PayrollPage.fromJson(data as Map<String, dynamic>),
      queryParams: params,
    );
  }

  Future<({Uint8List bytes, String filename})> exportPayslips({
    required int year,
    required int month,
    List<int>? ids,
  }) async {
    final params = <String, dynamic>{
      'year': year,
      'month': month,
      if (ids != null && ids.isNotEmpty) 'ids': ids,
    };
    final res = await _api.dio.get<List<int>>(
      '/payroll/export-payslips',
      queryParameters: params,
      options: Options(responseType: ResponseType.bytes),
    );
    final disposition = res.headers.value('content-disposition') ?? '';
    final match = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
    final filename = match?.group(1) ??
        'phieu_luong_thang_${month.toString().padLeft(2, '0')}-$year.xlsx';
    return (
      bytes: Uint8List.fromList(res.data ?? const <int>[]),
      filename: filename,
    );
  }

  Future<Payroll> generate(int employeeId, int year, int month,
      {int? formulaId}) async {
    return _api.post(
      '/payrolls/generate',
      (data) => Payroll.fromJson(data as Map<String, dynamic>),
      {
        'employeeId': employeeId,
        'year': year,
        'month': month,
        if (formulaId != null) 'formulaId': formulaId,
      },
    );
  }

  Future<Payroll> updateDraft(
    int id, {
    double? allowance,
    double? bonus,
    double? otherDeductions,
    String? note,
    CustomFormulaSnapshot? customFormula,
  }) async {
    return _api.patch(
      '/payrolls/$id',
      (data) => Payroll.fromJson(data as Map<String, dynamic>),
      {
        if (allowance != null) 'allowance': allowance,
        if (bonus != null) 'bonus': bonus,
        if (otherDeductions != null) 'otherDeductions': otherDeductions,
        if (note != null) 'note': note,
        if (customFormula != null) 'customFormula': customFormula.toJson(),
      },
    );
  }

  Future<Payroll> approve(int id) async {
    return _api.post(
      '/payrolls/$id/approve',
      (data) => Payroll.fromJson(data as Map<String, dynamic>),
      {},
    );
  }

  Future<Payroll> pay(int id) async {
    return _api.post(
      '/payrolls/$id/pay',
      (data) => Payroll.fromJson(data as Map<String, dynamic>),
      {},
    );
  }

  Future<void> delete(int id) async {
    await _api.delete('/payrolls/$id');
  }

  Future<Payroll> recalculate(int id, {int? formulaId}) async {
    return _api.post(
      '/payrolls/$id/recalculate',
      (data) => Payroll.fromJson(data as Map<String, dynamic>),
      {if (formulaId != null) 'formulaId': formulaId},
    );
  }

  Future<List<Payroll>> getSelf({int? year}) async {
    final params = <String, dynamic>{
      if (year != null) 'year': year,
    };
    return _api.get(
      '/payrolls/self',
      (data) => (data as List)
          .map((e) => Payroll.fromJson(e as Map<String, dynamic>))
          .toList(),
      queryParams: params,
    );
  }
}
