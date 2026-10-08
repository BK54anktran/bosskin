import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/attendance.dart';
export '../models/attendance.dart' show DayViewRow, TimesheetRow;
import '../services/api_service.dart';

class AttendanceRepository {
  final _api = ApiService.instance;

  Future<List<Attendance>> getByMonth({
    required int year,
    required int month,
    int? employeeId,
    int? departmentId,
  }) async {
    return _api.get(
      '/attendances',
      (data) => (data['content'] as List)
          .map((e) => Attendance.fromJson(e as Map<String, dynamic>))
          .toList(),
      queryParams: {
        'year': year,
        'month': month,
        if (employeeId != null) 'employeeId': employeeId,
        if (departmentId != null) 'departmentId': departmentId,
      },
    );
  }

  Future<AttendanceSummary> getSummary({
    required int employeeId,
    required int year,
    required int month,
  }) async {
    return _api.get(
      '/attendances/summary',
      (data) => AttendanceSummary.fromJson(data as Map<String, dynamic>),
      queryParams: {'employeeId': employeeId, 'year': year, 'month': month},
    );
  }

  Future<Attendance> checkIn(int employeeId) async {
    return _api.post(
      '/attendances/check-in',
      (data) => Attendance.fromJson(data as Map<String, dynamic>),
      {'employeeId': employeeId},
    );
  }

  Future<List<TimesheetRow>> getTimesheet({
    required int employeeId,
    required int year,
    required int month,
  }) async {
    return _api.get(
      '/attendances/timesheet',
      (data) => (data as List)
          .map((e) => TimesheetRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      queryParams: {'employeeId': employeeId, 'year': year, 'month': month},
    );
  }

  Future<List<TimesheetRow>> getTimesheetRange({
    required int employeeId,
    required String from,
    required String to,
  }) async {
    return _api.get(
      '/attendances/timesheet-range',
      (data) => (data as List)
          .map((e) => TimesheetRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      queryParams: {'employeeId': employeeId, 'from': from, 'to': to},
    );
  }

  Future<List<DayViewRow>> getDayView({
    required DateTime date,
    int? departmentId,
  }) async {
    return _api.get(
      '/attendances/day-view',
      (data) => (data as List)
          .map((e) => DayViewRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      queryParams: {
        'date': date.toIso8601String().split('T').first,
        if (departmentId != null) 'departmentId': departmentId,
      },
    );
  }

  Future<Attendance> checkOut(int employeeId) async {
    return _api.post(
      '/attendances/check-out',
      (data) => Attendance.fromJson(data as Map<String, dynamic>),
      {'employeeId': employeeId},
    );
  }

  Future<SelfTodayAttendance> getSelfToday({DateTime? date}) async {
    return _api.get(
      '/attendances/self/today',
      (data) => SelfTodayAttendance.fromJson(data as Map<String, dynamic>),
      queryParams: {
        if (date != null) 'date': date.toIso8601String().split('T').first,
      },
    );
  }

  Future<List<Attendance>> getSelfHistory({
    required int year,
    required int month,
  }) async {
    return _api.get(
      '/attendances/self/history',
      (data) => (data as List)
          .map((e) => Attendance.fromJson(e as Map<String, dynamic>))
          .toList(),
      queryParams: {'year': year, 'month': month},
    );
  }

  Future<SelfTodayAttendance> selfCheckIn({double? lat, double? lng, bool? isMocked, double? accuracy}) async {
    return _api.post(
      '/attendances/self/check-in',
      (data) => SelfTodayAttendance.fromJson(data as Map<String, dynamic>),
      {
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
        if (isMocked != null) 'isMocked': isMocked,
        if (accuracy != null) 'accuracy': accuracy,
      },
    );
  }

  Future<SelfTodayAttendance> selfCheckOut({double? lat, double? lng, bool? isMocked, double? accuracy}) async {
    return _api.post(
      '/attendances/self/check-out',
      (data) => SelfTodayAttendance.fromJson(data as Map<String, dynamic>),
      {
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
        if (isMocked != null) 'isMocked': isMocked,
        if (accuracy != null) 'accuracy': accuracy,
      },
    );
  }

  Future<SelfTodayAttendance> updateSelfAttendanceSetting(bool enabled) async {
    return _api.patch(
      '/attendances/self/setting',
      (data) => SelfTodayAttendance.fromJson(data as Map<String, dynamic>),
      {'enabled': enabled},
    );
  }

  Future<List<AttendanceChangeRequest>> getRequests({
    String? status,
    String? type,
    int? departmentId,
  }) async {
    return _api.get(
      '/attendance-requests',
      (data) => (data as List)
          .map((e) =>
              AttendanceChangeRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
      queryParams: {
        if (status != null) 'status': status,
        if (type != null) 'type': type,
        if (departmentId != null) 'departmentId': departmentId,
      },
    );
  }

  Future<List<AttendanceChangeRequest>> createRequest({
    required DateTime date,
    required String type,
    int? shiftAssignmentId,
    String? requestedCheckIn,
    String? requestedCheckOut,
    int? requestedOvertimeMinutes,
    String? requestedOvertimeScope,
    String? requestedOvertimePeriod,
    String? note,
  }) async {
    return _api.post(
      '/attendance-requests',
      (data) => (data as List)
          .map((e) => AttendanceChangeRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
      {
        'requestDate': date.toIso8601String().split('T').first,
        if (type != 'CHECK_IN_OUT') 'requestType': type,
        if (shiftAssignmentId != null) 'shiftAssignmentId': shiftAssignmentId,
        if (requestedCheckIn != null) 'requestedCheckIn': requestedCheckIn,
        if (requestedCheckOut != null) 'requestedCheckOut': requestedCheckOut,
        if (requestedOvertimeMinutes != null)
          'requestedOvertimeMinutes': requestedOvertimeMinutes,
        if (requestedOvertimeScope != null)
          'requestedOvertimeScope': requestedOvertimeScope,
        if (requestedOvertimePeriod != null)
          'requestedOvertimePeriod': requestedOvertimePeriod,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  Future<void> approveAttendance(
    int? attendanceId, {
    int? employeeId,
    DateTime? date,
    int? shiftAssignmentId,
  }) async {
    await _api.dio.post(
      '/attendances/approve',
      data: {
        if (attendanceId != null) 'attendanceId': attendanceId,
        if (employeeId != null) 'employeeId': employeeId,
        if (date != null) 'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        if (shiftAssignmentId != null) 'shiftAssignmentId': shiftAssignmentId,
      },
    );
  }

  Future<void> unapproveAttendance(int attendanceId) async {
    await _api.dio.post(
      '/attendances/unapprove',
      data: {'attendanceId': attendanceId},
    );
  }

  Future<void> deleteAttendance(int attendanceId) async {
    await _api.dio.delete('/attendances/$attendanceId');
  }

  Future<AttendanceChangeRequest> approveRequest(int id,
      {String? adminNote}) async {
    return _api.put(
      '/attendance-requests/$id/approve',
      (data) => AttendanceChangeRequest.fromJson(data as Map<String, dynamic>),
      {'adminNote': adminNote},
    );
  }

  Future<AttendanceChangeRequest> rejectRequest(int id,
      {String? adminNote}) async {
    return _api.put(
      '/attendance-requests/$id/reject',
      (data) => AttendanceChangeRequest.fromJson(data as Map<String, dynamic>),
      {'adminNote': adminNote},
    );
  }

  Future<AttendanceChangeRequest> cancelRequest(int id) async {
    return _api.put(
      '/attendance-requests/$id/cancel',
      (data) => AttendanceChangeRequest.fromJson(data as Map<String, dynamic>),
      {},
    );
  }

  Future<AttendanceChangeRequest> setRequestApplied(int id, bool applied) async {
    return _api.put(
      '/attendance-requests/$id/applied',
      (data) => AttendanceChangeRequest.fromJson(data as Map<String, dynamic>),
      {'applied': applied},
    );
  }

  Future<int> ensureAttendance(int employeeId, DateTime date) async {
    final res = await _api.dio.post('/attendances/override', data: {
      'employeeId': employeeId,
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    });
    return (res.data['attendanceId'] as num).toInt();
  }

  Future<void> saveOverride(int attendanceId, {
    String? checkIn,
    String? checkOut,
    int? breakMinutes,
    int? otDayMinutes,
    int? otNightMinutes,
    String? note,
  }) async {
    await _api.dio.patch('/attendances/$attendanceId/override', data: {
      'overrideCheckIn': checkIn,
      'overrideCheckOut': checkOut,
      'overrideBreakMinutes': breakMinutes,
      'overrideOtDayMinutes': otDayMinutes,
      'overrideOtNightMinutes': otNightMinutes,
      'overrideNote': note,
    });
  }

  Future<({Uint8List bytes, String filename})> exportTimesheetExcel({
    required int employeeId,
    required String from,
    required String to,
  }) async {
    final res = await _api.dio.get<List<int>>(
      '/attendances/export-timesheet',
      queryParameters: {'employeeId': employeeId, 'from': from, 'to': to},
      options: Options(responseType: ResponseType.bytes),
    );
    final disposition = res.headers.value('content-disposition') ?? '';
    final match = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
    final filename = match?.group(1) ?? 'cham_cong_$from-$to.xlsx';
    return (bytes: Uint8List.fromList(res.data ?? const <int>[]), filename: filename);
  }

  Future<({Uint8List bytes, String filename})> exportDayView({
    required String date,
    int? departmentId,
  }) async {
    final res = await _api.dio.get<List<int>>(
      '/attendances/export-day-view',
      queryParameters: {
        'date': date,
        if (departmentId != null) 'departmentId': departmentId,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    final disposition = res.headers.value('content-disposition') ?? '';
    final match = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
    final filename = match?.group(1) ?? 'cham_cong_ngay_$date.xlsx';
    return (bytes: Uint8List.fromList(res.data ?? const <int>[]), filename: filename);
  }

  Future<({Uint8List bytes, String filename})> exportExcel({
    required String from,
    required String to,
    List<int>? departmentIds,
  }) async {
    final params = <String, dynamic>{
      'from': from,
      'to': to,
      if (departmentIds != null && departmentIds.isNotEmpty)
        'departmentIds': departmentIds,
    };
    final res = await _api.dio.get<List<int>>(
      '/attendances/export',
      queryParameters: params,
      options: Options(responseType: ResponseType.bytes),
    );
    final disposition = res.headers.value('content-disposition') ?? '';
    final match = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
    final filename = match?.group(1) ?? 'cham_cong_$from-$to.xlsx';
    return (
      bytes: Uint8List.fromList(res.data ?? const <int>[]),
      filename: filename,
    );
  }

  Future<List<Map<String, dynamic>>> previewImport(
      Uint8List bytes, String filename) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _api.dio.post('/attendances/preview-import', data: form);
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> importAttendance(
      Uint8List bytes, String filename) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _api.dio.post('/attendances/import', data: form);
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> previewImportTimesheet(
      Uint8List bytes, String filename) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _api.dio.post('/attendances/preview-import-timesheet', data: form);
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> importTimesheet(
      Uint8List bytes, String filename) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _api.dio.post('/attendances/import-timesheet', data: form);
    return res.data as Map<String, dynamic>;
  }
}
