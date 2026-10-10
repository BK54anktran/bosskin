import '../../data/services/auth_service.dart';
import '../constants/app_constants.dart';

/// F8 — Một nơi duy nhất quyết định ai được vào màn nào.
/// Router (chặn URL), menu bên trái, drawer và thanh dưới đều gọi [canAccessRoute];
/// thêm màn mới chỉ cần khai báo ở đây. Quyền phải khớp với kiểm tra ở backend.

/// Mỗi route: danh sách quyền, có MỘT trong số đó là vào được.
/// Route không có trong bảng (vd. /profile) → mọi tài khoản công ty đã đăng nhập.
const Map<String, List<String>> routeAnyOf = {
  AppRoutes.dashboard: ['DASHBOARD_VIEW'],
  AppRoutes.employees: ['EMPLOYEE_VIEW'],
  AppRoutes.departments: ['DEPARTMENT_VIEW'],
  AppRoutes.shifts: ['SHIFT_VIEW', 'SHIFT_MANAGE'],
  AppRoutes.shiftSwaps: ['ATTENDANCE_SELF', 'SHIFT_SWAP_APPROVE'],
  AppRoutes.attendance: ['ATTENDANCE_VIEW'],
  AppRoutes.checkInOut: ['ATTENDANCE_SELF'],
  AppRoutes.attendanceRequests: [
    'ATTENDANCE_SELF',
    'ATTENDANCE_MANAGE',
    'ATTENDANCE_REQUEST_APPROVE',
  ],
  AppRoutes.payroll: ['PAYROLL_VIEW'],
  AppRoutes.selfPayroll: ['ATTENDANCE_SELF'],
  AppRoutes.roles: ['ROLE_VIEW'],
  AppRoutes.leaves: ['LEAVE_VIEW'],
  AppRoutes.companySettings: ['COMPANY_SETTING_VIEW', 'CALENDAR_VIEW'],
  // Backend lọc từng sheet theo quyền module; vào màn chỉ cần một trong hai quyền Excel.
  AppRoutes.excelImportExport: ['EXCEL_EXPORT', 'EXCEL_IMPORT'],
  AppRoutes.reports: ['REPORT_VIEW'],
  AppRoutes.auditLogs: ['AUDIT_VIEW'],
  // Duyệt yêu cầu sửa hồ sơ — backend yêu cầu EMPLOYEE_UPDATE.
  AppRoutes.editRequests: ['EMPLOYEE_UPDATE'],
};

/// Màn chỉ dành cho bản thân nhân viên — ẩn khi system admin đang impersonate.
const Set<String> selfOnlyRoutes = {
  AppRoutes.checkInOut,
  AppRoutes.selfPayroll,
  AppRoutes.profile,
};

bool canAccessRoute(AuthUser? user, String route) {
  if (user == null) return false;
  if (user.isSystemAdmin) return true;
  final anyOf = routeAnyOf[route];
  if (anyOf == null) return true;
  return anyOf.any(user.can);
}

/// Hiển thị trên menu: như [canAccessRoute], thêm ẩn màn cá nhân khi impersonate.
bool showInMenu(AuthUser? user, String route) {
  if (AuthService.instance.isImpersonating && selfOnlyRoutes.contains(route)) return false;
  return canAccessRoute(user, route);
}
