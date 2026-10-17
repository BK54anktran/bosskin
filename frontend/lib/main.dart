import 'package:flutter/material.dart';
import 'core/navigation/nav_access.dart';
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
import 'core/theme/theme_controller.dart';
import 'data/services/auth_service.dart';
import 'data/services/device_service.dart';
import 'data/services/notification_service.dart';
import 'presentation/screens/auth/force_change_password_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/notifications/notifications_screen.dart';
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
import 'presentation/screens/audit/audit_log_screen.dart';
import 'presentation/screens/shift/shift_swap_screen.dart';
import 'presentation/screens/shift/my_shift_registration_screen.dart';
import 'presentation/screens/employee/org_chart_screen.dart';
import 'presentation/screens/contracts/contracts_screen.dart';
import 'presentation/screens/documents/documents_screen.dart';
import 'presentation/screens/team_approvals/team_approvals_screen.dart';
import 'presentation/widgets/app_shell.dart';
import 'package:bosskin/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConfig.load();
  usePathUrlStrategy();
  await initializeDateFormatting('vi', null);
  await initializeDateFormatting('en', null);
  await LanguageService.instance.load();
  await ThemeController.instance.load();
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

final _router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.login,
  redirect: (context, state) {
    final path = state.matchedLocation;
    final user = AuthService.instance.currentUser;

    // Notification action button tapped while app was killed → navigate after login
    final pending = NotificationService.instance.consumePendingRoute();
    if (pending != null && user != null && !AuthService.instance.mustChangePassword && _canAccessPath(user, pending)) {
      return pending;
    }

    if (path == '/') {
      return user != null ? _firstAccessibleRoute(user) : AppRoutes.login;
    }

    // V7: tài khoản phải đổi mật khẩu → chỉ được ở màn đổi mật khẩu bắt buộc.
    final mustChange = user != null &&
        !user.isSystemAdmin &&
        AuthService.instance.mustChangePassword;
    if (path == AppRoutes.changePassword) {
      if (user == null) return AppRoutes.login;
      return mustChange ? null : _firstAccessibleRoute(user);
    }
    if (mustChange) return AppRoutes.changePassword;

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
    GoRoute(
      path: AppRoutes.changePassword,
      builder: (_, __) => const ForceChangePasswordScreen(),
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
          path: AppRoutes.contracts,
          pageBuilder: (_, __) => const NoTransitionPage(child: ContractsScreen()),
        ),
        GoRoute(
          path: AppRoutes.documents,
          pageBuilder: (_, __) => const NoTransitionPage(child: DocumentsScreen()),
        ),
        GoRoute(
          path: AppRoutes.orgChart,
          pageBuilder: (_, __) => const NoTransitionPage(child: OrgChartScreen()),
        ),
        GoRoute(
          path: AppRoutes.teamApprovals,
          pageBuilder: (_, __) => const NoTransitionPage(child: TeamApprovalsScreen()),
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
          path: AppRoutes.shiftSwaps,
          pageBuilder: (_, __) => const NoTransitionPage(child: ShiftSwapScreen()),
        ),
        GoRoute(
          path: AppRoutes.shiftRegistration,
          pageBuilder: (_, __) => const NoTransitionPage(child: MyShiftRegistrationScreen()),
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
          path: AppRoutes.notifications,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: NotificationsScreen()),
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
        GoRoute(
          path: AppRoutes.auditLogs,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: AuditLogScreen()),
        ),
      ],
    ),
  ],
);

bool _canAccessPath(AuthUser? user, String path) => canAccessRoute(user, path);

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
      animation: Listenable.merge([LanguageService.instance, ThemeController.instance]),
      builder: (_, __) {
        final locale = LanguageService.instance.locale;
        final dark = ThemeController.instance.effectiveDark;
        return MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context).appName,
          theme: dark ? AppTheme.dark : AppTheme.light,
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
            // Điện thoại (< 600) chặn ở 1.3 để thẻ / thanh nav không phình quá; màn rộng giữ 1.4
            final system = mq.textScaler.clamp(maxScaleFactor: width < 600 ? 1.3 : 1.4).scale(1.0);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(system * scale),
              ),
              // Bước F: màu AppTheme đọc theo AppTheme.isDark, không qua Theme.of → đổi chế độ thì dựng lại cả cây
              child: Theme(
                // Điện thoại: nút / ô nhập / combobox / tab gọn lại (AppTheme.compact)
                data: width < 600 ? AppTheme.compact(Theme.of(context)) : Theme.of(context),
                child: KeyedSubtree(key: ValueKey(dark), child: child!),
              ),
            );
          },
        );
      },
    );
  }
}
