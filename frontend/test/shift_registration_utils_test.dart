import 'package:bosskin/core/utils/shift_registration_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RegDaySlot t(String a, String b) => (any: false, start: a, end: b);
  const anyDay = (any: true, start: null, end: null);

  test('độ dài khung, qua đêm', () {
    expect(regSlotMinutes('08:00', '14:00'), 360);
    expect(regSlotMinutes('22:00', '06:00'), 480);
    expect(formatRegHours(450), '7,5');
  });

  test('chồng giờ kể cả qua đêm', () {
    expect(regSlotsOverlap('08:00', '12:00', '11:00', '14:00'), isTrue);
    expect(regSlotsOverlap('08:00', '12:00', '12:00', '14:00'), isFalse);
    expect(regSlotsOverlap('22:00', '02:00', '23:00', '23:30'), isTrue);
  });

  test('kiểm tra một ngày', () {
    expect(validateRegDay([t('08:00', '12:00'), t('17:00', '22:00')]), isNull);
    expect(validateRegDay([t('08:00', '12:00'), t('10:00', '14:00')]), RegDayProblem.overlap);
    expect(validateRegDay([t('06:00', '08:00'), t('09:00', '10:00'), t('11:00', '12:00')]), RegDayProblem.tooMany);
    expect(validateRegDay([anyDay, t('08:00', '12:00')]), RegDayProblem.anyAlone);
    expect(validateRegDay([t('08:00', '08:00')]), RegDayProblem.invalidTime);
    expect(validateRegDay([anyDay]), isNull);
  });
}
