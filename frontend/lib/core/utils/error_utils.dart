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
  'error.payroll.negative_adjustment': 'Phụ cấp, thưởng, khấu trừ không được âm',
  'error.leave.mode_mismatch': 'Loại phép này không xin theo cách đã chọn (ngày/giờ)',
  'error.leave.cancel_only_pending': 'Chỉ huỷ được đơn đang chờ duyệt; đơn đã duyệt cần người duyệt huỷ',
  'error.attendance.gps_inaccurate': 'Tín hiệu GPS chưa đủ chính xác, vui lòng ra chỗ thoáng và thử lại',
  'error.period.already_locked': 'Kỳ công này đã được khoá',
  'error.period.not_locked': 'Kỳ công này chưa khoá',
  'error.period.unlock_reason_required': 'Cần nhập lý do khi mở lại kỳ công',
  'error.auth.too_many_attempts': 'Sai mật khẩu quá nhiều lần, vui lòng thử lại sau 15 phút',
  'error.upload.invalid_folder': 'Thư mục tải lên không hợp lệ',
  'error.excel.module_not_permitted': 'File có sheet của chức năng bạn không có quyền nhập',
  'error.assignment.date_required': 'Thiếu ngày phân ca',
  'error.assignment.shift_required': 'Chưa chọn ca làm',
  'error.attendance.already_approved': 'Công ngày này đã được duyệt',
  'error.attendance.already_deleted': 'Bản ghi công đã bị xoá',
  'error.attendance.check_in_or_out_required': 'Cần nhập giờ vào hoặc giờ ra',
  'error.attendance.date_required': 'Thiếu ngày chấm công',
  'error.attendance.location_required': 'Cần bật định vị để chấm công',
  'error.attendance.missing_fields': 'Thiếu thông tin chấm công',
  'error.attendance.not_found': 'Không tìm thấy bản ghi công',
  'error.attendance.ot_duration_invalid': 'Số giờ tăng ca không hợp lệ',
  'error.attendance.ot_period_required': 'Chọn thời điểm tăng ca (trước/sau ca)',
  'error.attendance.ot_scope_required': 'Chọn phạm vi tăng ca',
  'error.company.cutoff_day_invalid': 'Ngày chốt công phải từ 1 đến 28',
  'error.company.hours_per_day_invalid': 'Số giờ/ngày không hợp lệ',
  'error.company.inactive': 'Công ty đã ngừng hoạt động',
  'error.company.not_found': 'Không tìm thấy công ty',
  'error.company.rounding_invalid': 'Cấu hình làm tròn không hợp lệ',
  'error.company.tolerance_invalid': 'Cấu hình dung sai không hợp lệ',
  'error.dashboard.invalid_range': 'Khoảng thời gian không hợp lệ',
  'error.date.invalid_format': 'Ngày không đúng định dạng',
  'error.department.not_found': 'Không tìm thấy phòng ban',
  'error.employee.code_required': 'Thiếu mã nhân viên',
  'error.excel.export_failed': 'Xuất Excel thất bại',
  'error.excel.file_empty': 'File trống',
  'error.excel.history_no_file': 'Bản ghi này không còn file gốc',
  'error.excel.history_not_found': 'Không tìm thấy lịch sử nhập/xuất',
  'error.excel.invalid_format': 'File không đúng định dạng Excel',
  'error.formula.invalid': 'Công thức không hợp lệ',
  'error.formula.invalid_date': 'Ngày hiệu lực không hợp lệ',
  'error.formula.name_duplicate': 'Tên công thức đã tồn tại',
  'error.formula.name_required': 'Thiếu tên công thức',
  'error.grade.base_rate_invalid': 'Mức lương cơ bản không hợp lệ',
  'error.grade.code_required': 'Thiếu mã bậc lương',
  'error.grade.not_found': 'Không tìm thấy bậc lương',
  'error.payroll.already_exists': 'Bảng lương kỳ này đã tồn tại',
  'error.payroll.approve_non_draft': 'Chỉ duyệt được bảng lương nháp',
  'error.payroll.delete_non_draft': 'Chỉ xoá được bảng lương nháp',
  'error.payroll.edit_non_draft': 'Chỉ sửa được bảng lương nháp',
  'error.payroll.formula_evaluation_failed': 'Không tính được công thức lương — kiểm tra lại biến và công thức',
  'error.payroll.formula_not_configured': 'Bậc lương chưa có công thức',
  'error.payroll.import_not_supported': 'Không hỗ trợ nhập bảng lương từ Excel',
  'error.payroll.not_found': 'Không tìm thấy bảng lương',
  'error.payroll.pay_non_approved': 'Chỉ chi trả được bảng lương đã duyệt',
  'error.payroll.recalculate_non_draft': 'Chỉ tính lại được bảng lương nháp',
  'error.payroll.salary_not_configured': 'Nhân viên chưa có bậc lương / lương hợp đồng',
  'error.permission.department_scope': 'Nhân viên nằm ngoài phạm vi phòng ban bạn được xem',
  'error.role.not_found': 'Không tìm thấy vai trò',
  'error.salary_formula.not_found': 'Không tìm thấy công thức lương',
  'error.salary_grade.duplicate_code': 'Mã bậc lương đã tồn tại',
  'error.salary_grade.invalid_pay_type': 'Kiểu trả lương không hợp lệ',
  'error.salary_grade.not_found': 'Không tìm thấy bậc lương',
  'error.shift.code_required': 'Thiếu mã ca',
  'error.shift.name_required': 'Thiếu tên ca',
  'error.user.employee_not_linked': 'Tài khoản chưa gắn với nhân viên',
  'error.user.not_found': 'Không tìm thấy tài khoản',
  'error.variable.name_required': 'Thiếu tên biến',
  'error.shift.flexible_required_minutes': 'Ca linh hoạt cần có khung giờ và số giờ phải làm',
  'error.shift.flexible_window_too_short': 'Khung giờ ngắn hơn số giờ phải làm',
  'error.shift.too_many_per_day': 'Tối đa 4 ca mỗi ngày',
  'error.rotation.not_found': 'Không tìm thấy mẫu xoay ca',
  'error.rotation.empty': 'Mẫu xoay ca cần ít nhất một ca',
  'error.rotation.shift_invalid': 'Mẫu có ca không tồn tại hoặc đã xoá',
  'error.rotation.range_invalid': 'Khoảng ngày không hợp lệ (tối đa 93 ngày)',
  'error.swap.not_your_shift': 'Đây không phải ca của bạn',
  'error.swap.same_employee': 'Không thể đổi ca với chính mình',
  'error.swap.target_shift_mismatch': 'Ca được chọn không thuộc người nhận',
  'error.swap.already_pending': 'Ca này đang có yêu cầu đổi chờ duyệt',
  'error.swap.self_approve': 'Không được duyệt yêu cầu đổi ca có liên quan đến mình',
  'error.swap.shift_changed': 'Phân ca đã thay đổi sau khi gửi yêu cầu',
  'error.swap.not_found': 'Không tìm thấy yêu cầu đổi ca',
  'error.swap.not_pending': 'Yêu cầu đã được xử lý',
  'error.swap.past_shift': 'Không đổi được ca đã qua',
  'error.attendance.device_not_bound': 'Thiết bị này chưa được gắn để chấm công cho bạn. Nhờ quản lý gỡ thiết bị cũ nếu bạn đổi điện thoại.',
  'error.attendance.device_missing': 'Không xác định được thiết bị — hãy cập nhật ứng dụng',
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
  'error.payroll.negative_adjustment': 'Allowance, bonus and deductions cannot be negative',
  'error.leave.mode_mismatch': 'This leave type cannot be requested this way (days/hours)',
  'error.leave.cancel_only_pending': 'Only pending requests can be cancelled; approved ones must be cancelled by an approver',
  'error.attendance.gps_inaccurate': 'GPS signal is not accurate enough, please move to an open area and try again',
  'error.period.already_locked': 'This attendance period is already locked',
  'error.period.not_locked': 'This attendance period is not locked',
  'error.period.unlock_reason_required': 'A reason is required to reopen the period',
  'error.auth.too_many_attempts': 'Too many failed attempts, please try again in 15 minutes',
  'error.upload.invalid_folder': 'Invalid upload folder',
  'error.excel.module_not_permitted': 'The file contains a sheet you are not allowed to import',
  'error.assignment.date_required': 'Assignment date is required',
  'error.assignment.shift_required': 'Please choose a shift',
  'error.attendance.already_approved': 'This attendance is already approved',
  'error.attendance.already_deleted': 'This attendance record was already deleted',
  'error.attendance.check_in_or_out_required': 'Check-in or check-out time is required',
  'error.attendance.date_required': 'Attendance date is required',
  'error.attendance.location_required': 'Location is required to check in',
  'error.attendance.missing_fields': 'Attendance information is incomplete',
  'error.attendance.not_found': 'Attendance record not found',
  'error.attendance.ot_duration_invalid': 'Invalid overtime duration',
  'error.attendance.ot_period_required': 'Choose when the overtime happens (before/after shift)',
  'error.attendance.ot_scope_required': 'Choose the overtime scope',
  'error.company.cutoff_day_invalid': 'Cutoff day must be between 1 and 28',
  'error.company.hours_per_day_invalid': 'Invalid hours per day',
  'error.company.inactive': 'This company is inactive',
  'error.company.not_found': 'Company not found',
  'error.company.rounding_invalid': 'Invalid rounding setting',
  'error.company.tolerance_invalid': 'Invalid tolerance setting',
  'error.dashboard.invalid_range': 'Invalid date range',
  'error.date.invalid_format': 'Invalid date format',
  'error.department.not_found': 'Department not found',
  'error.employee.code_required': 'Employee code is required',
  'error.excel.export_failed': 'Excel export failed',
  'error.excel.file_empty': 'The file is empty',
  'error.excel.history_no_file': 'This history entry has no file',
  'error.excel.history_not_found': 'Import/export history not found',
  'error.excel.invalid_format': 'The file is not a valid Excel file',
  'error.formula.invalid': 'Invalid formula',
  'error.formula.invalid_date': 'Invalid effective date',
  'error.formula.name_duplicate': 'A formula with this name already exists',
  'error.formula.name_required': 'Formula name is required',
  'error.grade.base_rate_invalid': 'Invalid base rate',
  'error.grade.code_required': 'Salary grade code is required',
  'error.grade.not_found': 'Salary grade not found',
  'error.payroll.already_exists': 'Payroll for this period already exists',
  'error.payroll.approve_non_draft': 'Only draft payrolls can be approved',
  'error.payroll.delete_non_draft': 'Only draft payrolls can be deleted',
  'error.payroll.edit_non_draft': 'Only draft payrolls can be edited',
  'error.payroll.formula_evaluation_failed': 'The salary formula could not be evaluated — check variables and formula',
  'error.payroll.formula_not_configured': 'No salary formula configured for this grade',
  'error.payroll.import_not_supported': 'Importing payroll from Excel is not supported',
  'error.payroll.not_found': 'Payroll not found',
  'error.payroll.pay_non_approved': 'Only approved payrolls can be paid',
  'error.payroll.recalculate_non_draft': 'Only draft payrolls can be recalculated',
  'error.payroll.salary_not_configured': 'The employee has no salary grade or contract salary',
  'error.permission.department_scope': 'The employee is outside your department scope',
  'error.role.not_found': 'Role not found',
  'error.salary_formula.not_found': 'Salary formula not found',
  'error.salary_grade.duplicate_code': 'Salary grade code already exists',
  'error.salary_grade.invalid_pay_type': 'Invalid pay type',
  'error.salary_grade.not_found': 'Salary grade not found',
  'error.shift.code_required': 'Shift code is required',
  'error.shift.name_required': 'Shift name is required',
  'error.user.employee_not_linked': 'This account is not linked to an employee',
  'error.user.not_found': 'User not found',
  'error.variable.name_required': 'Variable name is required',
  'error.shift.flexible_required_minutes': 'A flexible shift needs a time window and required hours',
  'error.shift.flexible_window_too_short': 'The window is shorter than the required hours',
  'error.shift.too_many_per_day': 'At most 4 shifts per day',
  'error.rotation.not_found': 'Rotation pattern not found',
  'error.rotation.empty': 'A rotation needs at least one shift',
  'error.rotation.shift_invalid': 'The pattern contains a missing or deleted shift',
  'error.rotation.range_invalid': 'Invalid date range (max 93 days)',
  'error.swap.not_your_shift': 'This is not your shift',
  'error.swap.same_employee': 'You cannot swap with yourself',
  'error.swap.target_shift_mismatch': 'The chosen shift does not belong to that colleague',
  'error.swap.already_pending': 'This shift already has a pending swap request',
  'error.swap.self_approve': 'You cannot approve a swap that involves you',
  'error.swap.shift_changed': 'The assignment changed after the request was sent',
  'error.swap.not_found': 'Swap request not found',
  'error.swap.not_pending': 'The request has already been processed',
  'error.swap.past_shift': 'Past shifts cannot be swapped',
  'error.attendance.device_not_bound': 'This device is not your bound check-in device. Ask a manager to unbind your old phone if you changed phones.',
  'error.attendance.device_missing': 'Could not identify this device — please update the app',
};

/// Tra bản dịch; key dạng "error.x.y.<chi tiết>" thử lại với phần đầu "error.x.y".
String? _translateKey(String key, bool en) {
  final map = en ? _enMessages : _viMessages;
  var k = key;
  while (true) {
    final hit = map[k];
    if (hit != null) return hit;
    final dot = k.lastIndexOf('.');
    if (dot <= 'error.'.length) return null;
    k = k.substring(0, dot);
  }
}

/// Dịch một mã lỗi backend đơn lẻ (vd. lý do trong danh sách xung đột); không có bản dịch thì trả nguyên.
String serverKeyMsg(String key) => _translateKey(key, LanguageService.instance.isEnglish) ?? key;

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
      final translated = _translateKey(msg, en);
      if (translated != null) return translated;
      // Key lỗi chưa có bản dịch → không hiện "error.xxx" thô cho người dùng (F6)
      if (!msg.startsWith('error.') && !msg.startsWith('warning.')) return msg;
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
