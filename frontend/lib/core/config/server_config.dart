import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  static const _key = 'server_host';
  static const _defaultHost = 'http://192.168.0.12:8080';

  static String _host = _defaultHost;

  static String get host => _host;
  static String get baseUrl => '$_host/api/v1';
  static String get adminUrl => '$_host/admin';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString(_key) ?? _defaultHost;
  }

  static Future<void> save(String host) async {
    final cleaned = host.endsWith('/') ? host.substring(0, host.length - 1) : host;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, cleaned);
    _host = cleaned;
  }
}
