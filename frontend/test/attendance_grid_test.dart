import 'package:bosskin/presentation/screens/attendance/widgets/attendance_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lưới chấm công trên màn điện thoại: vuốt ngang ngay trên bảng phải cuộn được (lỗi 12/10/2026: phần thân bị khoá cuộn),
/// tiêu đề đi theo; vuốt dọc ở nửa nào thì nửa kia cũng cuộn theo.
void main() {
  late ScrollController h;
  late ScrollController v;

  Widget host() => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 500,
            child: AttendanceGrid(
              fixedColumnHeader: 'NV',
              fixedColumnWidth: 120,
              columnHeaders: List.generate(31, (i) => 'D${i + 1}'),
              columnWidths: List.filled(31, 60),
              rowCount: 40,
              rowHeightAt: (_) => 44,
              isWeekend: (_) => false,
              isToday: (_) => false,
              fixedCellBuilder: (i, w, bg, _) => SizedBox(width: w, child: Text('emp$i')),
              dataCellsBuilder: (i, ws, bg, _) =>
                  [for (var c = 0; c < ws.length; c++) SizedBox(width: ws[c], child: Text('r${i}c$c'))],
              hScrollController: h,
              vScrollController: v,
            ),
          ),
        ),
      );

  setUp(() {
    h = ScrollController();
    v = ScrollController();
  });
  tearDown(() {
    h.dispose();
    v.dispose();
  });

  testWidgets('vuốt ngang trên phần dữ liệu cuộn bảng, tiêu đề đi theo', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('D1'), findsOneWidget);
    final headBefore = tester.getTopLeft(find.text('D1')).dx;

    await tester.drag(find.text('r2c1'), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(h.offset, greaterThan(200));
    // Tiêu đề dịch sang trái đúng bằng phần dữ liệu
    expect(tester.getTopLeft(find.text('D1')).dx, closeTo(headBefore - h.offset, 1));
    // Cột cố định không dịch
    expect(tester.getTopLeft(find.text('emp2')).dx, lessThan(120));
  });

  testWidgets('cuộn được tới cột cuối', (tester) async {
    await tester.pumpWidget(host());
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(AttendanceGrid), const Offset(-300, 0), warnIfMissed: false);
      await tester.pumpAndSettle();
    }
    // 31 cột × 60 = 1860, khung nhìn 360 − 120 = 240 → cuộn tối đa 1620
    expect(h.offset, closeTo(1620, 1));
    expect(find.text('D31'), findsOneWidget);
  });

  testWidgets('vuốt dọc ở phần dữ liệu thì cột cố định cuộn theo, và ngược lại', (tester) async {
    await tester.pumpWidget(host());

    await tester.drag(find.text('r3c1'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(v.offset, greaterThan(150));
    // Hàng 0 đã trôi khỏi cả hai nửa
    expect(find.text('emp0'), findsNothing);
    expect(find.text('r0c0'), findsNothing);
    final rowY = tester.getTopLeft(find.text('r8c0')).dy;
    expect(tester.getTopLeft(find.text('emp8')).dy, closeTo(rowY, 1));

    final before = v.offset;
    await tester.drag(find.text('emp8'), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(v.offset, greaterThan(before + 100));
  });
}
