import 'package:dio/dio.dart';

import '../models/work_calendar.dart';
import '../services/api_service.dart';

/// Ngày lễ theo năm (/holidays) và lịch làm việc tuần (/work-calendars) — bước J.
class WorkCalendarRepository {
  final _api = ApiService.instance;

  /// Danh sách ngày lễ của năm; `customized` = công ty đã chỉnh (không còn theo mẫu hệ thống).
  Future<({bool customized, List<Holiday> items})> getHolidays(int year) {
    return _api.get('/holidays', (d) {
      final m = d as Map<String, dynamic>;
      return (
        customized: m['customized'] == true,
        items: ((m['items'] as List?) ?? const [])
            .map((e) => Holiday.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }, queryParams: {'year': year});
  }

  Future<void> createHoliday(Holiday h) => _api.post('/holidays', (_) {}, h.toJson());

  Future<void> updateHoliday(int id, Holiday h) => _api.put('/holidays/$id', (_) {}, h.toJson());

  Future<void> deleteHoliday(int id) => _api.delete('/holidays/$id');

  Future<Response<List<int>>> exportHolidays(int year) => _api.dio.get<List<int>>(
        '/holidays/export',
        queryParameters: {'year': year},
        options: Options(responseType: ResponseType.bytes),
      );

  Future<List<dynamic>> previewImportHolidays(List<int> bytes, String filename) async {
    final r = await _api.dio.post('/holidays/preview-import',
        data: FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: filename)}));
    return r.data as List<dynamic>;
  }

  Future<void> importHolidays(List<int> bytes, String filename) => _api.dio.post('/holidays/import',
      data: FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: filename)}));

  Future<List<WorkCalendar>> getCalendars() => _api.get('/work-calendars',
      (d) => (d as List).map((e) => WorkCalendar.fromJson(e as Map<String, dynamic>)).toList());

  Future<void> saveDefault(String weekPattern) =>
      _api.put('/work-calendars/default', (_) {}, {'weekPattern': weekPattern});

  Future<void> createCalendar(String name, String weekPattern, List<int> departmentIds) =>
      _api.post('/work-calendars', (_) {},
          {'name': name, 'weekPattern': weekPattern, 'departmentIds': departmentIds});

  Future<void> updateCalendar(int id, String name, String weekPattern, List<int> departmentIds) =>
      _api.put('/work-calendars/$id', (_) {},
          {'name': name, 'weekPattern': weekPattern, 'departmentIds': departmentIds});

  Future<void> deleteCalendar(int id) => _api.delete('/work-calendars/$id');

  /// Lịch đã giải cho [from, to]; lỗi (thiếu quyền, mạng) → lịch mặc định T2–T6 không ngày lễ.
  Future<WorkCalendarView> view(DateTime from, DateTime to) async {
    try {
      return await _api.get('/work-calendars/view',
          (d) => WorkCalendarView.fromJson(d as Map<String, dynamic>),
          queryParams: {'from': dateKey(from), 'to': dateKey(to)});
    } catch (_) {
      return WorkCalendarView.empty;
    }
  }
}
