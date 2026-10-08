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
  'error.auth.refresh_token_expired': 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại',
  'error.auth.invalid_refresh_token': 'Phiên đăng nhập không hợp lệ, vui lòng đăng nhập lại',
  'error.auth.account_disabled': 'Tài khoản đã bị khoá',
  'error.user.cannot_disable_self': 'Không thể tự khoá tài khoản của chính mình',
  'error.permission.cannot_change_own': 'Không thể tự thay đổi vai trò hoặc quyền của chính mình',
  'error.permission.grant_exceeds_own': 'Không thể cấp quyền mà bạn không có',
  'error.attendance.cannot_approve_own': 'Không thể duyệt hoặc sửa công của chính mình',
  'error.shiftAssignment.not_found': 'Không tìm thấy phân ca của nhân viên trong ngày này',
  'error.shiftAssignment.has_attendance': 'Ca này đã có dữ liệu chấm công hoặc đơn chấm công, không xoá được',
  'error.data.conflict': 'Dữ liệu bị trùng hoặc đang được sử dụng',
  'error.not_found': 'Không tìm thấy dữ liệu',
  'error.bad_request': 'Yêu cầu không hợp lệ',
  'error.internal': 'Có lỗi hệ thống, vui lòng thử lại sau',
  'error.period.locked': 'Kỳ công đã khoá, không thể thay đổi dữ liệu trong kỳ này',
  'error.attendance.mock_location': 'Phát hiện vị trí giả lập, không thể chấm công',
  'error.attendance_request.cannot_process_own': 'Không thể tự duyệt đơn chấm công của chính mình',
  'error.leave.cannot_process_own': 'Không thể tự duyệt đơn nghỉ phép của chính mình',
  'error.leave.overlap': 'Đã có đơn nghỉ khác trùng ngày',
  'error.leave.mode_mismatch': 'Loại phép này không xin theo cách đã chọn (ngày/giờ)',
  'error.leave.cancel_only_pending': 'Chỉ huỷ được đơn đang chờ duyệt; đơn đã duyệt cần người duyệt huỷ',
  'error.attendance.gps_inaccurate': 'Tín hiệu GPS chưa đủ chính xác, vui lòng ra chỗ thoáng và thử lại',
  'error.period.already_locked': 'Kỳ công này đã được khoá',
  'error.period.not_locked': 'Kỳ công này chưa khoá',
  'error.period.unlock_reason_required': 'Cần nhập lý do khi mở lại kỳ công',
  'error.auth.too_many_attempts': 'Sai mật khẩu quá nhiều lần, vui lòng thử lại sau 15 phút',
  'error.upload.invalid_folder': 'Thư mục tải lên không hợp lệ',
  'error.excel.module_not_permitted': 'File có sheet của chức năng bạn không có quyền nhập',
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
  'error.auth.refresh_token_expired': 'Session expired, please sign in again',
  'error.auth.invalid_refresh_token': 'Invalid session, please sign in again',
  'error.auth.account_disabled': 'The account has been locked',
  'error.user.cannot_disable_self': 'You cannot lock your own account',
  'error.permission.cannot_change_own': 'You cannot change your own roles or permissions',
  'error.permission.grant_exceeds_own': 'You cannot grant permissions you do not have',
  'error.attendance.cannot_approve_own': 'You cannot approve or edit your own attendance',
  'error.shiftAssignment.not_found': 'Shift assignment not found for this employee and date',
  'error.shiftAssignment.has_attendance': 'This shift already has attendance data or requests and cannot be deleted',
  'error.data.conflict': 'The data is duplicated or still in use',
  'error.not_found': 'Not found',
  'error.bad_request': 'Invalid request',
  'error.internal': 'A system error occurred, please try again later',
  'error.period.locked': 'This attendance period is locked and cannot be changed',
  'error.attendance.mock_location': 'Mock location detected, attendance not allowed',
  'error.attendance_request.cannot_process_own': 'You cannot process your own attendance request',
  'error.leave.cannot_process_own': 'You cannot process your own leave request',
  'error.leave.overlap': 'Another leave request already covers these dates',
  'error.leave.mode_mismatch': 'This leave type cannot be requested this way (days/hours)',
  'error.leave.cancel_only_pending': 'Only pending requests can be cancelled; approved ones must be cancelled by an approver',
  'error.attendance.gps_inaccurate': 'GPS signal is not accurate enough, please move to an open area and try again',
  'error.period.already_locked': 'This attendance period is already locked',
  'error.period.not_locked': 'This attendance period is not locked',
  'error.period.unlock_reason_required': 'A reason is required to reopen the period',
  'error.auth.too_many_attempts': 'Too many failed attempts, please try again in 15 minutes',
  'error.upload.invalid_folder': 'Invalid upload folder',
  'error.excel.module_not_permitted': 'The file contains a sheet you are not allowed to import',
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
