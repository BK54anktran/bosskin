import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bosskin/core/localization/language_service.dart';
import 'package:bosskin/core/utils/default_text_utils.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Tên mặc định đổi theo ngôn ngữ app, tên người dùng tự đặt giữ nguyên', () async {
    await LanguageService.instance.setLocale(const Locale('en'));
    expect(localizeDefaultText('Nhân viên'), 'Employee');
    expect(localizeDefaultText('Sơ yếu lý lịch'), 'Curriculum vitae');
    expect(localizeDefaultText('Kế toán trưởng'), 'Kế toán trưởng');

    await LanguageService.instance.setLocale(const Locale('vi'));
    expect(localizeDefaultText('Employee'), 'Nhân viên');
    expect(localizeDefaultText('Curriculum vitae'), 'Sơ yếu lý lịch');
    expect(localizeDefaultText('Nhân viên'), 'Nhân viên');
  });
}
