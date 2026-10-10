import 'package:bosskin/core/constants/app_constants.dart';
import 'package:bosskin/core/navigation/nav_menu.dart';
import 'package:bosskin/data/services/auth_service.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget host(String location, List<String> visited) => MaterialApp(
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: SizedBox(width: 220, child: GroupedNavList(location: location, go: visited.add)),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AuthService.instance.debugSetUser(null));

  testWidgets('nhân viên thường chỉ thấy nhóm của mình; bấm mục thì chuyển màn', (tester) async {
    AuthService.instance.debugSetUser(const AuthUser(
        email: 'nv@x.test', token: 't', type: UserType.company, employeeId: 7,
        permissions: {'ATTENDANCE_SELF', 'LEAVE_VIEW', 'DASHBOARD_VIEW'}));
    final visited = <String>[];
    await tester.pumpWidget(host(AppRoutes.checkInOut, visited));
    await tester.pumpAndSettle();

    expect(find.text('CỦA TÔI'), findsOneWidget);
    expect(find.text('ĐƠN TỪ & PHÊ DUYỆT'), findsOneWidget);
    expect(find.text('NHÂN SỰ'), findsNothing, reason: 'không có quyền xem nhân viên → ẩn cả nhóm');
    expect(find.text('CÀI ĐẶT & HỆ THỐNG'), findsNothing);
    expect(find.text('Bảng lương'), findsNothing);

    await tester.tap(find.text('Nghỉ phép'));
    expect(visited, [AppRoutes.leaves]);
  });

  testWidgets('thu gọn nhóm bằng tiêu đề, nhớ trạng thái; nhóm chứa màn đang mở không thu gọn', (tester) async {
    AuthService.instance.debugSetUser(const AuthUser(
        email: 'ad@x.test', token: 't', type: UserType.company, employeeId: 1,
        permissions: {'ATTENDANCE_SELF', 'EMPLOYEE_VIEW', 'DEPARTMENT_VIEW', 'PAYROLL_VIEW', 'REPORT_VIEW'}));
    await tester.pumpWidget(host(AppRoutes.dashboard, []));
    await tester.pumpAndSettle();

    expect(find.text('Nhân viên'), findsOneWidget);
    await tester.tap(find.text('NHÂN SỰ'));
    await tester.pumpAndSettle();
    expect(find.text('Nhân viên'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('nav_collapsed_groups'), contains('hr'));

    // Mở màn Nhân viên → nhóm Nhân sự tự mở dù đã thu gọn
    await tester.pumpWidget(host(AppRoutes.employees, []));
    await tester.pumpAndSettle();
    expect(find.text('Nhân viên'), findsOneWidget);

    // Bỏ thu gọn để test sau không bị ảnh hưởng (trạng thái là singleton)
    await tester.pumpWidget(host(AppRoutes.dashboard, []));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NHÂN SỰ'));
    await tester.pumpAndSettle();
    expect(find.text('Nhân viên'), findsOneWidget);
  });
}
