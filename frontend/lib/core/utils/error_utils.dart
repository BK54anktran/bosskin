import 'package:dio/dio.dart';

import '../localization/language_service.dart';

const _viMessages = <String, String>{
  'warning.employee.already_exists': 'Nhân viên đã tồn tại — bỏ qua',
  'error.permission.denied': 'Không có quyền thực hiện thao tác này',
  'error.department.must_be_child_in_scope': 'Chỉ được tạo phòng ban con trong phạm vi được phép',
  'error.department.parent_out_of_scope': 'Phòng ban cha không nằm trong phạm vi được phép',
  'error.employee.not_found': 'Không tìm thấy nhân viên',
  'error.payroll.already_generated': 'Bảng lương đã được tạo cho kỳ này',
  'error.excel.import_failed': 'Import file thất bại, vui lòng kiểm tra lại file',
  'error.shift.invalid_sheet_name': 'Tên sheet không đúng định dạng "Phan cong ca MM-yyyy". Vui lòng không đổi tên sheet khi import.',
};

const _enMessages = <String, String>{
  'warning.employee.already_exists': 'Employee already exists — skipped',
  'error.permission.denied': 'You do not have permission to perform this action',
  'error.department.must_be_child_in_scope': 'You can only create sub-departments within your permitted scope',
  'error.department.parent_out_of_scope': 'The parent department is outside your permitted scope',
  'error.employee.not_found': 'Employee not found',
  'error.payroll.already_generated': 'Payroll has already been generated for this period',
  'error.excel.import_failed': 'Import failed, please check the file and try again',
  'error.shift.invalid_sheet_name': 'Sheet name must follow the format "Phan cong ca MM-yyyy". Do not rename the sheet before importing.',
};

String serverMsg(dynamic e) {
  final en = LanguageService.instance.isEnglish;

  if (e is DioException) {
    final status = e.response?.statusCode;
    final code = status ?? 0;
    final data = e.response?.data;

    String? msg;
    if (data is Map) {
      msg = (data['message'] as String?)?.trim();
      if (msg == null || msg.isEmpty) {
        msg = (data['error'] as String?)?.trim();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      msg = data.trim();
    }

    if (msg != null && msg.isNotEmpty) {
      final translated = en ? _enMessages[msg] : _viMessages[msg];
      return translated ?? msg;
    }

    return switch (code) {
      400 => en ? 'Invalid data' : 'Dữ liệu không hợp lệ',
      401 => en
          ? 'Session expired, please sign in again'
          : 'Phiên đăng nhập hết hạn, vui lòng đăng nhập lại',
      403 => en
          ? 'You do not have permission to perform this action'
          : 'Không có quyền thực hiện thao tác này',
      404 => en ? 'Data not found' : 'Không tìm thấy dữ liệu',
      409 => en
          ? 'Data conflict, please check again'
          : 'Xung đột dữ liệu, vui lòng kiểm tra lại',
      500 => en ? 'Server error, please try again later' : 'Lỗi server, vui lòng thử lại sau',
      _ => en ? 'Unknown error (code $code)' : 'Lỗi không xác định (mã $code)',
    };
  }

  return en
      ? 'Unable to connect to server, please check your network'
      : 'Không thể kết nối server, kiểm tra kết nối mạng';
}
