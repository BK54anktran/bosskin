import 'package:bosskin/core/constants/app_constants.dart';
import 'package:bosskin/core/navigation/nav_access.dart';
import 'package:bosskin/core/navigation/nav_menu.dart';
import 'package:bosskin/data/services/auth_service.dart';
import 'package:bosskin/l10n/app_localizations_vi.dart';
import 'package:flutter_test/flutter_test.dart';

AuthUser user(Set<String> perms, {UserType type = UserType.company}) =>
    AuthUser(email: 'a@b.test', token: 't', type: type, employeeId: 1, permissions: perms);

void main() {
  tearDown(() => AuthService.instance.debugSetUser(null));

  group('canAccessRoute', () {
    test('nhân viên chỉ có quyền tự phục vụ', () {
      final u = user({'ATTENDANCE_SELF', 'LEAVE_VIEW'});
      expect(canAccessRoute(u, AppRoutes.checkInOut), isTrue);
      expect(canAccessRoute(u, AppRoutes.leaves), isTrue);
      expect(canAccessRoute(u, AppRoutes.profile), isTrue, reason: 'route không khai báo quyền = mọi tài khoản');
      expect(canAccessRoute(u, AppRoutes.employees), isFalse);
      expect(canAccessRoute(u, AppRoutes.payroll), isFalse);
      expect(canAccessRoute(u, AppRoutes.auditLogs), isFalse);
    });

    test('một trong nhiều quyền là đủ', () {
      expect(canAccessRoute(user({'SHIFT_MANAGE'}), AppRoutes.shifts), isTrue);
      expect(canAccessRoute(user({'EXCEL_IMPORT'}), AppRoutes.excelImportExport), isTrue);
      expect(canAccessRoute(user({'CALENDAR_VIEW'}), AppRoutes.companySettings), isTrue);
    });

    test('system admin vào mọi màn; chưa đăng nhập không vào màn nào', () {
      final sa = user({}, type: UserType.system);
      for (final r in routeAnyOf.keys) {
        expect(canAccessRoute(sa, r), isTrue, reason: r);
        expect(canAccessRoute(null, r), isFalse, reason: r);
      }
    });
  });

  test('impersonate: ẩn các màn cá nhân trên menu', () {
    final company = user({'ATTENDANCE_SELF', 'DASHBOARD_VIEW'});
    AuthService.instance.debugSetUser(company, impersonatedBy: user({}, type: UserType.system));
    expect(showInMenu(company, AppRoutes.checkInOut), isFalse);
    expect(showInMenu(company, AppRoutes.selfPayroll), isFalse);
    expect(showInMenu(company, AppRoutes.dashboard), isTrue);
  });

  group('menu nhóm (nav_menu.dart)', () {
    final groups = navGroups(AppLocalizationsVi());
    final routes = groups.expand((g) => g.entries).map((e) => e.route).toList();

    test('mỗi màn xuất hiện đúng một lần', () {
      expect(routes.toSet().length, routes.length);
    });

    test('mọi màn có khai báo quyền trong nav_access (trừ màn mở cho mọi tài khoản)', () {
      const open = {AppRoutes.profile, AppRoutes.notifications, AppRoutes.teamApprovals};
      for (final r in routes) {
        expect(routeAnyOf.containsKey(r) || open.contains(r), isTrue, reason: r);
      }
    });

    test('mọi màn có khai báo quyền đều có trên menu', () {
      for (final r in routeAnyOf.keys) {
        expect(routes.contains(r), isTrue, reason: '$r chưa có trên menu');
      }
    });

    test('chỉ nhóm đầu không có tiêu đề; mã nhóm không trùng', () {
      expect(groups.first.title, isNull);
      expect(groups.skip(1).every((g) => g.title != null && g.title!.isNotEmpty), isTrue);
      expect(groups.map((g) => g.id).toSet().length, groups.length);
    });
  });

  group('activeNavRoute', () {
    final routes = [AppRoutes.dashboard, AppRoutes.profile, AppRoutes.editRequests, AppRoutes.payroll, AppRoutes.selfPayroll];
    test('khớp đúng thắng tiền tố', () {
      expect(activeNavRoute(AppRoutes.selfPayroll, routes), AppRoutes.selfPayroll);
      expect(activeNavRoute(AppRoutes.payroll, routes), AppRoutes.payroll);
    });
    test('tiền tố dài nhất', () {
      expect(activeNavRoute('${AppRoutes.editRequests}/12', routes), AppRoutes.editRequests);
      expect(activeNavRoute('${AppRoutes.profile}/x', routes), AppRoutes.profile);
    });
    test('không khớp thì null; /dashboardx không nhầm thành /dashboard', () {
      expect(activeNavRoute('/khac', routes), isNull);
      expect(activeNavRoute('/dashboardx', routes), isNull);
    });
  });
}
