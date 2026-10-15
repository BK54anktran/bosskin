import '../../data/services/auth_service.dart';
import '../../data/services/company_feature_service.dart';
import '../../data/services/team_approval_service.dart';
import '../constants/app_constants.dart';

/// F8 — Một nơi duy nhất quyết định ai được vào màn nào.
/// Router (chặn URL), menu bên trái, drawer và thanh dưới đều gọi [canAccessRoute];
/// thêm màn mới chỉ cần khai báo ở đây. Quyền phải khớp với kiểm tra ở backend.

/// Mỗi route: danh sách quyền, có MỘT trong số đó là vào được.
/// Route không có trong bảng (vd. /profile) → mọi tài khoản công ty đã đăng nhập.
const Map<String, List<String>> routeAnyOf = {
  AppRoutes.dashboard: ['DASHBOARD_VIEW'],
  AppRoutes.employees: ['EMPLOYEE_VIEW'],
  AppRoutes.orgChart: ['EMPLOYEE_VIEW'],
  AppRoutes.contracts: ['CONTRACT_VIEW'],
  AppRoutes.documents: ['EMPLOYEE_DOCUMENT_VIEW'],
  AppRoutes.departments: ['DEPARTMENT_VIEW'],
  AppRoutes.shifts: ['SHIFT_VIEW', 'SHIFT_MANAGE'],
  AppRoutes.shiftSwaps: ['ATTENDANCE_SELF', 'SHIFT_SWAP_APPROVE'],
  AppRoutes.shiftRegistration: ['SHIFT_REGISTRATION_SELF'],
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

/// V26: màn thuộc tính năng của công ty (khớp backend core/FeatureRoutes) → ẩn khi công ty tắt tính năng đó.
/// Cần cả khi quyền đã bị gỡ theo tính năng: nhiều màn dùng quyền chung / quyền lõi (vd. ATTENDANCE_SELF, EMPLOYEE_VIEW).
const Map<String, String> routeFeature = {
  AppRoutes.attendance: 'ATT_SHEET',
  AppRoutes.checkInOut: 'ATT_SELF',
  AppRoutes.attendanceRequests: 'ATT_REQUEST',
  AppRoutes.shifts: 'SHIFT_BASIC',
  AppRoutes.shiftSwaps: 'SHIFT_SWAP',
  AppRoutes.shiftRegistration: 'SHIFT_REGISTRATION',
  AppRoutes.leaves: 'LEAVE_BASIC',
  AppRoutes.payroll: 'PAY_BASIC',
  AppRoutes.selfPayroll: 'PAY_BASIC',
  AppRoutes.contracts: 'HR_CONTRACT',
  AppRoutes.documents: 'HR_DOCUMENT',
  AppRoutes.orgChart: 'HR_ORGCHART',
  AppRoutes.teamApprovals: 'HR_MANAGER_APPROVAL',
  AppRoutes.reports: 'RPT_OVERVIEW',
  AppRoutes.excelImportExport: 'DATA_EXCEL',
};

/// Màn chỉ dành cho bản thân nhân viên — ẩn khi system admin đang impersonate.
const Set<String> selfOnlyRoutes = {
  AppRoutes.checkInOut,
  AppRoutes.selfPayroll,
  AppRoutes.profile,
  AppRoutes.shiftRegistration,
};

bool canAccessRoute(AuthUser? user, String route) {
  if (user == null) return false;
  if (user.isSystemAdmin) return true;
  final feature = routeFeature[route];
  if (feature != null && !user.hasFeature(feature)) return false;
  final anyOf = routeAnyOf[route];
  if (anyOf == null) return true;
  return anyOf.any(user.can);
}

/// Hiển thị trên menu: như [canAccessRoute], thêm ẩn màn cá nhân khi impersonate.
bool showInMenu(AuthUser? user, String route) {
  if (AuthService.instance.isImpersonating && selfOnlyRoutes.contains(route)) return false;
  // V23: chỉ hiện khi công ty bật đăng ký lịch làm việc
  if (route == AppRoutes.shiftRegistration && !CompanyFeatureService.instance.shiftRegistration) return false;
  // Bước K: quyền đến từ quan hệ quản lý trực tiếp (backend kiểm), menu chỉ hiện khi có cấp dưới + chế độ bật
  if (route == AppRoutes.teamApprovals) {
    return user != null && !user.isSystemAdmin && TeamApprovalService.instance.visible;
  }
  return canAccessRoute(user, route);
}
