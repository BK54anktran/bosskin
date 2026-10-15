import 'package:bosskin/core/utils/company_module_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bật Chấm công tự bật Ca làm; tắt Ca làm tự tắt Chấm công', () {
    final m = <String>{'LEAVE'};
    toggleCompanyModule(m, 'ATTENDANCE', true);
    expect(m, containsAll(['ATTENDANCE', 'SHIFT', 'LEAVE']));
    toggleCompanyModule(m, 'SHIFT', false);
    expect(m, {'LEAVE'});
  });
}
