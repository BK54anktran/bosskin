class AppConstants {
  static const String appName = 'BossKin';
  static const String baseUrl = 'http://localhost:8080/api/v1';
  static const String adminBaseUrl = 'http://localhost:8080/admin';

  static const String tokenKey = 'access_token';
  static const String adminTokenKey = 'admin_access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'current_user';
  static const String deviceIdKey = 'device_id';
  static const String adminUserKey = 'current_admin_user';

  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;

  static const int pageSize = 20;
}

class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String employees = '/employees';
  static const String attendance = '/attendance';
  static const String checkInOut = '/check-in-out';
  static const String attendanceRequests = '/attendance-requests';
  static const String payroll = '/payroll';
  static const String selfPayroll = '/payroll/self';
  static const String departments = '/departments';
  static const String shifts = '/shifts';
  static const String shiftSwaps = '/shift-swaps';
  static const String roles = '/roles';
  static const String leaves = '/leaves';
  static const String companySettings = '/company-settings';
  static const String profile = '/profile';
  static const String changePassword = '/change-password';
  static const String editRequests = '/profile/edit-requests';
  static const String excelImportExport = '/excel';
  static const String reports = '/reports';
  static const String auditLogs = '/audit-logs';
  static const String orgChart = '/org-chart';
  static const String teamApprovals = '/team-approvals';
  static const String contracts = '/contracts';
  static const String documents = '/documents';

  // Admin routes
  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminCompanies = '/admin/companies';
}
