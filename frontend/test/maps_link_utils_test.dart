import 'package:bosskin/core/utils/maps_link_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const long =
      'https://www.google.com/maps/place/MAMA+COOK/@10.8522074,106.6232696,138m/data=!3m1!1e3!4m6!3m5!1s0x31752b0024a2f7dd:0xcd0b6b6413f5ee3d!8m2!3d10.8522385!4d106.6237611!16s%2Fg%2F11lmqb322l?entry=tts';

  test('link dài: ưu tiên ghim !3d!4d hơn tâm bản đồ @', () {
    final p = parseMapsCoordinates(long)!;
    expect(p.latitude, 10.8522385);
    expect(p.longitude, 106.6237611);
  });

  test('chỉ có @lat,lng', () {
    final p = parseMapsCoordinates('https://www.google.com/maps/@10.7769,106.7009,15z')!;
    expect([p.latitude, p.longitude], [10.7769, 106.7009]);
  });

  test('?q=, ?ll= và chuỗi lat, lng trơn', () {
    expect(parseMapsCoordinates('https://maps.google.com/?q=10.77,106.70')!.longitude, 106.70);
    expect(parseMapsCoordinates('https://maps.google.com/?q=10.77%2C106.70&z=15')!.latitude, 10.77);
    expect(parseMapsCoordinates('https://www.google.com/maps?ll=-33.86,151.21')!.latitude, -33.86);
    expect(parseMapsCoordinates(' 10.852238, 106.623761 ')!.longitude, 106.623761);
  });

  test('ngoài phạm vi, link rút gọn, rỗng → null; link rút gọn nhận ra là URL', () {
    expect(parseMapsCoordinates('95.0, 106.0'), isNull);
    expect(parseMapsCoordinates('10.0, 200.0'), isNull);
    expect(parseMapsCoordinates('https://maps.app.goo.gl/tk52Nipa8yXuwh1b8'), isNull);
    expect(parseMapsCoordinates('xin chào'), isNull);
    expect(parseMapsCoordinates(''), isNull);
    expect(parseMapsCoordinates(null), isNull);
    expect(looksLikeUrl('https://maps.app.goo.gl/tk52Nipa8yXuwh1b8'), isTrue);
    expect(looksLikeUrl('10.77, 106.70'), isFalse);
  });
}
