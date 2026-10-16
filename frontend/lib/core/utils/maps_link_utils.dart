import 'package:latlong2/latlong.dart';

/// Đọc toạ độ từ link Google Maps dạng đầy đủ hoặc chuỗi "vĩ độ, kinh độ" (cùng quy tắc với backend `GoogleMapsLink`).
/// Link rút gọn (maps.app.goo.gl) không có toạ độ trong chữ → trả null, cần nhờ backend mở link (`GeoRepository`).
final _num = r'-?\d{1,3}(?:\.\d+)?';
final _pin = RegExp('!3d($_num)!4d($_num)');
final _at = RegExp('@($_num),($_num)');
// /maps/search/10.85,+106.63 · /maps/place/10.85,106.63 · /maps/dir//10.85,106.63 (toạ độ nằm trong đường dẫn)
final _pathPair = RegExp('/($_num),(?:\\+|%2[Bb]|%20)?($_num)(?=[/?#]|\$)');
final _pair = RegExp('^\\s*($_num)\\s*[,; ]\\s*($_num)\\s*\$');
final _queryPair = RegExp(r'(?:^|[?&])(?:q|ll|query|destination|center|daddr)=([^&#]+)');

LatLng? parseMapsCoordinates(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final t = text.trim();
  var m = _pin.firstMatch(t); // ghim địa điểm ưu tiên hơn tâm bản đồ
  if (m != null) return _valid(m.group(1)!, m.group(2)!);
  m = _pathPair.firstMatch(t); // toạ độ trong đường dẫn ưu tiên hơn tâm bản đồ @
  if (m != null) return _valid(m.group(1)!, m.group(2)!);
  m = _at.firstMatch(t);
  if (m != null) return _valid(m.group(1)!, m.group(2)!);
  m = _pair.firstMatch(t);
  if (m != null) return _valid(m.group(1)!, m.group(2)!);
  for (final q in _queryPair.allMatches(t)) {
    String v;
    try {
      v = Uri.decodeComponent(q.group(1)!.replaceAll('+', ' '));
    } catch (_) {
      continue;
    }
    final p = _pair.firstMatch(v);
    if (p != null) return _valid(p.group(1)!, p.group(2)!);
  }
  return null;
}

LatLng? _valid(String lat, String lng) {
  final a = double.tryParse(lat), b = double.tryParse(lng);
  if (a == null || b == null || a.abs() > 90 || b.abs() > 180) return null;
  return LatLng(a, b);
}

/// Có vẻ là đường dẫn http(s) (để quyết định có nhờ backend mở link rút gọn không).
bool looksLikeUrl(String text) => RegExp(r'^https?://', caseSensitive: false).hasMatch(text.trim());
