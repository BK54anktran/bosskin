import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Địa chỉ backend.
///
/// - Bản build: truyền lúc build, ví dụ
///   `flutter build web --dart-define=API_HOST=https://api.ten-mien.vn`
/// - Không truyền: mặc định `http://localhost:8080` (chạy local).
/// - Ô "đổi server" ở màn đăng nhập chỉ có ở bản debug/profile (để test trên điện thoại
///   qua IP LAN); bản release luôn dùng API_HOST, bỏ qua giá trị đã lưu (F7).
class ServerConfig {
  static const _key = 'server_host';
  static const _envHost = String.fromEnvironment('API_HOST');
  static const _defaultHost = _envHost != '' ? _envHost : 'http://localhost:8080';

  /// Cho phép người dùng đổi địa chỉ server (chỉ bản không phải release).
  static bool get canOverride => !kReleaseMode;

  static String _host = _defaultHost;

  static String get host => _host;
  static String get baseUrl => '$_host/api/v1';
  static String get adminUrl => '$_host/admin';

  static Future<void> load() async {
    if (!canOverride) {
      _host = _defaultHost;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString(_key) ?? _defaultHost;
  }

  static Future<void> save(String host) async {
    if (!canOverride) return;
    final cleaned = host.endsWith('/') ? host.substring(0, host.length - 1) : host;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, cleaned);
    _host = cleaned;
  }
}
