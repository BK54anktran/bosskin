import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/constants/app_constants.dart';
import 'core/navigation/navigator_keys.dart';
import 'core/config/server_config.dart';
import 'core/localization/language_service.dart';
import 'core/theme/app_theme.dart';
import 'data/services/auth_service.dart';
import 'data/services/device_service.dart';
import 'data/services/notification_service.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/profile/edit_requests_screen.dart';
import 'presentation/screens/admin/admin_login_screen.dart';
import 'presentation/screens/admin/admin_dashboard_screen.dart';
import 'presentation/screens/department/department_screen.dart';
import 'presentation/screens/employee/employee_screen.dart';
import 'presentation/screens/attendance/attendance_screen.dart';
import 'presentation/screens/attendance/check_in_out_screen.dart';
import 'presentation/screens/attendance/attendance_requests_screen.dart';
import 'presentation/screens/shift/shift_screen.dart';
import 'presentation/screens/roles/roles_screen.dart';
import 'presentation/screens/leaves/leaves_screen.dart';
import 'presentation/screens/company_settings/company_settings_screen.dart';
import 'presentation/screens/payroll/payroll_tab_screen.dart';
import 'presentation/screens/payroll/self_payroll_screen.dart';
import 'presentation/screens/excel/excel_import_export_screen.dart';
import 'presentation/screens/report/report_screen.dart';
import 'presentation/widgets/app_shell.dart';
import 'package:bosskin/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConfig.load();
  usePathUrlStrategy();
  await initializeDateFormatting('vi', null);
  await LanguageService.instance.load();
  await DeviceService.instance.getOrCreateDeviceId();
  await NotificationService.instance.initialize();
  AuthService.instance.deviceFcmToken = NotificationService.instance.deviceToken;
  await AuthService.instance.restoreAndVerify();
  _wireNotificationLifecycle();
  runApp(const ProviderScope(child: BossKinApp()));
}

/// F10 — vòng đời FCM token theo phiên đăng nhập:
/// đăng nhập/khôi phục phiên → gắn token máy này; đăng xuất → backend gỡ token;
/// FCM đổi token khi đang đăng nhập → cập nhật lại.
void _wireNotificationLifecycle() {
  final auth = AuthService.instance;
  final notif = NotificationService.instance;
  notif.onTokenRefreshWhileSignedIn = () {
    final u = auth.currentUser;
    return u != null && !u.isSystemAdmin;
  };
  String? keyOf(AuthUser? u) =>
      (u == null || u.isSystemAdmin) ? null : '${u.companyId}:${u.email}';
  var lastUserKey = keyOf(auth.currentUser);
  if (lastUserKey != null) notif.syncDeviceToken(); // phiên khôi phục khi mở app
  auth.addListener(() {
    final key = keyOf(auth.currentUser);
    if (key != null && key != lastUserKey) notif.syncDeviceToken();
    lastUserKey = key;
  });
}

// Routes that require a specific permission to access
const _routePermissions = <String, String>{
  AppRoutes.dashboard: 'DASHBOARD_VIEW',
  AppRoutes.employees: 'EMPLOYEE_VIEW',
  AppRoutes.departments: 'DEPARTMENT_VIEW',
  AppRoutes.shifts: 'SHIFT_VIEW',
  AppRoutes.attendance: 'ATTENDANCE_VIEW',
  AppRoutes.checkInOut: 'ATTENDANCE_SELF',
  AppRoutes.payroll: 'PAYROLL_VIEW',
  AppRoutes.selfPayroll: 'ATTENDANCE_SELF',
  AppRoutes.roles: 'ROLE_VIEW',
  AppRoutes.leaves: 'LEAVE_VIEW',
  AppRoutes.companySettings: 'COMPANY_SETTING_VIEW',
  AppRoutes.excelImportExport: 'EMPLOYEE_VIEW',
  AppRoutes.reports: 'REPORT_VIEW',
};

final _router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.login,
  redirect: (context, state) {
    final path = state.matchedLocation;
    final user = AuthService.instance.currentUser;

    // Notification action button tapped while app was killed → navigate after login
    final pending = NotificationService.instance.consumePendingRoute();
    if (pending != null && user != null && _canAccessPath(user, pending)) {
      return pending;
    }

    if (path == '/') {
      return user != null ? _firstAccessibleRoute(user) : AppRoutes.login;
    }

    final isAdminPath = path.startsWith('/admin');
    final isAdminLogin = path == AppRoutes.adminLogin;
    final isLoginPage = path == AppRoutes.login;

    // Đã đăng nhập → bỏ qua màn login
    if (isLoginPage && user != null) {
      return _firstAccessibleRoute(user);
    }

    if (isAdminPath && !isAdminLogin) {
      if (user == null || !user.isSystemAdmin) return AppRoutes.adminLogin;
    }

    if (!isLoginPage && !isAdminPath) {
      if (user == null) return AppRoutes.login;

      // Block access to permission-guarded routes
      if (!user.isSystemAdmin && !_canAccessPath(user, path)) {
        return _firstAccessibleRoute(user);
      }
    }

    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.login,
      builder: (_, __) => const LoginScreen(),
    ),
    // Admin routes (outside shell)
    GoRoute(
      path: AppRoutes.adminLogin,
      builder: (_, __) => const AdminLoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminDashboard,
      builder: (_, __) => const AdminDashboardScreen(),
    ),
    // Authenticated company routes (inside persistent shell)
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) => AppShell(
        location: state.uri.path,
        child: child,
      ),
      routes: [
        GoRoute(
          path: AppRoutes.dashboard,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: DashboardScreen()),
        ),
        GoRoute(
          path: AppRoutes.employees,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: EmployeeScreen()),
        ),
        GoRoute(
          path: AppRoutes.departments,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: DepartmentScreen()),
        ),
        GoRoute(
          path: AppRoutes.attendance,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: AttendanceScreen()),
        ),
        GoRoute(
          path: AppRoutes.checkInOut,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: CheckInOutScreen()),
        ),
        GoRoute(
          path: AppRoutes.attendanceRequests,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: AttendanceRequestsScreen()),
        ),
        GoRoute(
          path: AppRoutes.shifts,
          pageBuilder: (_, __) => const NoTransitionPage(child: ShiftScreen()),
        ),
        GoRoute(
          path: AppRoutes.roles,
          pageBuilder: (_, __) => const NoTransitionPage(child: RolesScreen()),
        ),
        GoRoute(
          path: AppRoutes.leaves,
          pageBuilder: (_, __) => const NoTransitionPage(child: LeavesScreen()),
        ),
        GoRoute(
          path: AppRoutes.payroll,
          pageBuilder: (_, __) => const NoTransitionPage(child: PayrollTabScreen()),
        ),
        GoRoute(
          path: AppRoutes.selfPayroll,
          pageBuilder: (_, __) => const NoTransitionPage(child: SelfPayrollScreen()),
        ),
        GoRoute(
          path: AppRoutes.companySettings,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: CompanySettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.profile,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: ProfileScreen()),
        ),
        GoRoute(
          path: AppRoutes.editRequests,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: EditRequestsScreen()),
        ),
        GoRoute(
          path: AppRoutes.excelImportExport,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: ExcelImportExportScreen()),
        ),
        GoRoute(
          path: AppRoutes.reports,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: ReportScreen()),
        ),
      ],
    ),
  ],
);

bool _canAccessPath(dynamic user, String path) {
  if (user == null) return false;
  if (user.isSystemAdmin) return true;

  if (path == AppRoutes.attendanceRequests) {
    return user.can('ATTENDANCE_SELF') ||
        user.can('ATTENDANCE_MANAGE') ||
        user.can('ATTENDANCE_REQUEST_APPROVE');
  }

  if (path == AppRoutes.shifts) {
    return user.can('SHIFT_VIEW') || user.can('SHIFT_MANAGE');
  }

  final required = _routePermissions[path];
  return required == null || user.can(required);
}

String _firstAccessibleRoute(dynamic user) {
  if (user == null) return AppRoutes.login;
  if (user.isSystemAdmin) return AppRoutes.adminDashboard;

  final routes = <String>[
    AppRoutes.dashboard,
    AppRoutes.employees,
    AppRoutes.departments,
    AppRoutes.shifts,
    AppRoutes.roles,
    AppRoutes.leaves,
    AppRoutes.companySettings,
    AppRoutes.attendance,
    AppRoutes.checkInOut,
    AppRoutes.attendanceRequests,
    AppRoutes.payroll,
    AppRoutes.profile,
  ];

  for (final route in routes) {
    if (_canAccessPath(user, route)) {
      return route;
    }
  }

  return AppRoutes.login;
}

class BossKinApp extends StatelessWidget {
  const BossKinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageService.instance,
      builder: (_, __) {
        final locale = LanguageService.instance.locale;
        return MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context).appName,
          theme: AppTheme.light,
          routerConfig: _router,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final width = mq.size.width;
            // mobile < 600: scale 0.9, tablet 600-900: scale 0.95, desktop: 1.0
            final scale = width < 600 ? 0.9 : (width < 900 ? 0.95 : 1.0);
            // F12 — tôn trọng cỡ chữ hệ thống (người lớn tuổi / thị lực kém), nhân thêm
            // hệ số theo màn hình; chặn trên 1.4 để bảng biểu không vỡ.
            final system = mq.textScaler.clamp(maxScaleFactor: 1.4).scale(1.0);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(system * scale),
              ),
              child: child!,
            );
          },
        );
      },
    );
  }
}
