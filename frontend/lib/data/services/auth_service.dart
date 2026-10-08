import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/server_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/language_service.dart';
import 'profile_service.dart';
import 'device_service.dart';

enum UserType { company, system }

class AuthUser {
  final String email;
  final String? fullName;
  final String? avatar;
  final String token;
  final UserType type;
  final int? companyId;
  final String? companyName;
  final int? employeeId;
  final Set<String> permissions;

  /// permCode → list of allowed deptIds
  final Map<String, List<int>> deptScopes;

  const AuthUser({
    required this.email,
    this.fullName,
    this.avatar,
    required this.token,
    required this.type,
    this.companyId,
    this.companyName,
    this.employeeId,
    this.permissions = const {},
    this.deptScopes = const {},
  });

  bool get isSystemAdmin => type == UserType.system;

  bool get isAdmin => permissions.contains('EMPLOYEE_UPDATE');

  bool can(String permission) => permissions.contains(permission);

  Map<String, dynamic> toJson() => {
        'email': email,
        'fullName': fullName,
        'avatar': avatar,
        'token': token,
        'type': type.name,
        'companyId': companyId,
        'companyName': companyName,
        'employeeId': employeeId,
        'permissions': permissions.toList(),
        'deptScopes': deptScopes.map(
          (k, v) => MapEntry(k, v),
        ),
      };

  factory AuthUser.fromJson(Map<String, dynamic> m) => AuthUser(
        email: m['email'] as String,
        fullName: m['fullName'] as String?,
        avatar: m['avatar'] as String?,
        token: m['token'] as String,
        type:
            m['type'] == 'system' ? UserType.system : UserType.company,
        companyId: m['companyId'] as int?,
        companyName: m['companyName'] as String?,
        employeeId: m['employeeId'] as int?,
        permissions: (m['permissions'] as List?)
                ?.map((e) => e.toString())
                .toSet() ??
            {},
        deptScopes: _parseDeptScopes(m['deptScopes']),
      );

  static Map<String, List<int>> _parseDeptScopes(dynamic raw) {
    if (raw is! Map) return {};

    return raw.map(
      (k, v) => MapEntry(
        k.toString(),
        (v as List)
            .map((e) => (e as num).toInt())
            .toList(),
      ),
    );
  }
}

class AuthService extends ChangeNotifier {
  static AuthService? _instance;

  static AuthService get instance =>
      _instance ??= AuthService._();

  static void reset() {
    _instance = null;
  }

  AuthService._();

  final _storage = const FlutterSecureStorage(
    webOptions: WebOptions(
      dbName: 'bosskin',
      publicKey: 'bosskin_key',
    ),
  );

  final _dio = Dio(
    BaseOptions(
      baseUrl: ServerConfig.host,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  AuthUser? _currentUser;
  AuthUser? _adminUser; // giữ sysadmin khi đang impersonate
  String? _currentRefreshToken;

  /// false khi đăng nhập không chọn "ghi nhớ": token chỉ giữ trong bộ nhớ (F4).
  bool _persistSession = true;

  /// Tài khoản do admin đặt mật khẩu → phải đổi trước khi dùng (V7). Router chặn mọi màn khác.
  bool _mustChangePassword = false;
  bool get mustChangePassword => _mustChangePassword;
  static const _mustChangeKey = 'must_change_password';

  /// Backend báo 403 error.auth.password_change_required (vd. sau khi tải lại trang).
  void markPasswordChangeRequired() {
    if (_mustChangePassword) return;
    _mustChangePassword = true;
    if (_persistSession) _safeWrite(_mustChangeKey, '1');
    notifyListeners();
  }

  /// Đổi mật khẩu bắt buộc xong: backend thu hồi mọi phiên → đăng nhập lại bằng mật khẩu mới.
  Future<void> completeForcedPasswordChange(String newPassword) async {
    final email = _currentUser?.email;
    final remember = _persistSession;
    _mustChangePassword = false;
    await _safeDelete(_mustChangeKey);
    if (email != null) await login(email, newPassword, rememberMe: remember);
  }

  /// Đang refresh token — các request 401 cùng lúc dùng chung một lần refresh (F2).
  Future<bool>? _refreshInFlight;

  /// Access token đang dùng cho API (token công ty khi đang impersonate).
  String? get activeToken => _currentUser?.token;

  /// User hiển thị trên UI — luôn là sysadmin nếu đang impersonate
  AuthUser? get currentUser => _adminUser ?? _currentUser;

  /// Company user đang impersonate (null nếu không impersonate)
  AuthUser? get impersonatingUser => _adminUser != null ? _currentUser : null;

  bool get isImpersonating => _adminUser != null;

  bool get _isLinuxDev =>
      !kIsWeb && Platform.isLinux;

  // Windows desktop dùng SharedPreferences thay vì SecureStorage (ổn định hơn)
  bool get _useSharedPrefs =>
      !kIsWeb && !Platform.isAndroid && !Platform.isIOS && Platform.isWindows;

  // =========================================================
  // SAFE STORAGE HELPERS
  // =========================================================

  Future<String?> _safeRead(String key) async {
    if (_isLinuxDev) {
      if (key == AppConstants.tokenKey || key == AppConstants.adminTokenKey) {
        return _currentUser?.token;
      }
      if (key == AppConstants.refreshTokenKey) return _currentRefreshToken;
      return null;
    }
    if (_useSharedPrefs) {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(key);
      } catch (e) {
        debugPrint('SharedPrefs read error: $e');
        return null;
      }
    }
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('Storage read error: $e');
      return null;
    }
  }

  Future<void> _safeWrite(String key, String value) async {
    if (_isLinuxDev) return;
    if (_useSharedPrefs) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
      } catch (e) {
        debugPrint('SharedPrefs write error: $e');
      }
      return;
    }
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('Storage write error: $e');
    }
  }

  Future<void> _safeDelete(String key) async {
    if (_isLinuxDev) return;
    if (_useSharedPrefs) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(key);
      } catch (e) {
        debugPrint('SharedPrefs delete error: $e');
      }
      return;
    }
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('Storage delete error: $e');
    }
  }

  Map<String, String> _requestHeaders({bool includeToken = false}) {
    final headers = <String, String>{
      'Accept-Language': LanguageService.instance.locale.toLanguageTag(),
    };
    if (includeToken && _currentUser?.token != null) {
      headers['Authorization'] = 'Bearer ${_currentUser!.token}';
    }
    return headers;
  }

  // =========================================================
  // RESTORE SESSION + AUTO LOGIN
  // =========================================================

  /// Restore session từ storage, sau đó verify token với server.
  /// Nếu token hết hạn → thử refresh. Nếu refresh thất bại → clear session.
  Future<void> restoreAndVerify() async {
    await restoreSession();
    if (_currentUser == null) return;

    final ok = await _verifyToken();
    if (!ok) {
      // Token hết hạn, thử refresh
      final refreshed = await refreshToken();
      if (!refreshed) {
        // Refresh cũng hết hạn → logout
        await logout();
      }
    }
  }

  Future<bool> _verifyToken() async {
    if (_currentUser == null) return false;
    try {
      await _dio.get(
        '/api/v1/profile',
        options: Options(headers: _requestHeaders(includeToken: true)),
      );
      return true;
    } catch (e) {
      if (e is DioException) {
        final status = e.response?.statusCode;
        if (status == 401 || status == 403) return false;
        // Network error hoặc server down → coi như token còn hợp lệ
        return true;
      }
      return true;
    }
  }

  Future<void> restoreSession() async {
    // Load admin session
    final adminJson = await _safeRead(AppConstants.adminUserKey);
    final adminToken = await _safeRead(AppConstants.adminTokenKey);
    AuthUser? adminUser;
    if (adminJson != null && adminToken != null) {
      try {
        adminUser = AuthUser.fromJson(jsonDecode(adminJson) as Map<String, dynamic>);
      } catch (_) {
        await _safeDelete(AppConstants.adminUserKey);
        await _safeDelete(AppConstants.adminTokenKey);
      }
    }

    // Load company session (impersonate)
    final userJson = await _safeRead(AppConstants.userKey);
    final token = await _safeRead(AppConstants.tokenKey);
    AuthUser? companyUser;
    if (userJson != null && token != null) {
      try {
        companyUser = AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {
        await _safeDelete(AppConstants.userKey);
        await _safeDelete(AppConstants.tokenKey);
      }
    }

    if (companyUser != null && adminUser != null) {
      // Đang impersonate: admin là _adminUser, company là _currentUser
      _adminUser = adminUser;
      _currentUser = companyUser;
    } else if (companyUser != null) {
      _currentUser = companyUser;
    } else if (adminUser != null) {
      _currentUser = adminUser;
    }
    if (_currentUser != null) _persistSession = true;
    _mustChangePassword =
        _currentUser != null && await _safeRead(_mustChangeKey) == '1';
  }

  // =========================================================
  // COMPANY LOGIN
  // =========================================================

  Future<AuthUser> login(
    String email,
    String password, {
    bool rememberMe = true,
  }) async {
    final deviceId =
        await DeviceService.instance.getOrCreateDeviceId();

    final res = await _dio.post(
      '/api/v1/auth/login',
      data: {
        'email': email,
        'password': password,
        'deviceId': deviceId,
      },
      options: Options(headers: _requestHeaders()),
    );

    final token =
        res.data['accessToken'] as String;

    final refreshToken =
        res.data['refreshToken'] as String?;

    final userMap =
        res.data['user'] as Map<String, dynamic>;

    final rawPerms = userMap['permissions'];

    final perms = rawPerms is List
        ? rawPerms
            .map((e) => e.toString())
            .toSet()
        : <String>{};

    _currentUser = AuthUser(
      email: userMap['email'] as String,
      fullName: userMap['fullName'] as String?,
      avatar: userMap['avatar'] as String?,
      token: token,
      type: UserType.company,
      companyId: userMap['companyId'] as int?,
      companyName:
          userMap['companyName'] as String?,
      employeeId: userMap['employeeId'] as int?,
      permissions: perms,
    );

    _mustChangePassword = userMap['mustChangePassword'] == true;
    _persistSession = rememberMe;
    if (rememberMe) {
      await Future.wait([
        _mustChangePassword
            ? _safeWrite(_mustChangeKey, '1')
            : _safeDelete(_mustChangeKey),
        _safeWrite(AppConstants.tokenKey, token),
        _safeWrite(AppConstants.userKey, jsonEncode(_currentUser!.toJson())),
        if (refreshToken != null)
          _safeWrite(AppConstants.refreshTokenKey, refreshToken),
      ]);
    }
    _currentRefreshToken = refreshToken;

    notifyListeners();

    return _currentUser!;
  }

  Future<void> refreshCurrentUserProfile() async {
    if (_currentUser == null) return;

    try {
      final res = await _dio.get(
        '/api/v1/profile',
        options: Options(headers: _requestHeaders(includeToken: true)),
      );
      final data = res.data as Map<String, dynamic>;
      _currentUser = AuthUser(
        email: _currentUser!.email,
        fullName: data['fullName'] as String? ?? _currentUser!.fullName,
        avatar: data['avatar'] as String? ?? _currentUser!.avatar,
        token: _currentUser!.token,
        type: _currentUser!.type,
        companyId: _currentUser!.companyId,
        companyName: _currentUser!.companyName,
        employeeId: _currentUser!.employeeId,
        permissions: _currentUser!.permissions,
        deptScopes: _currentUser!.deptScopes,
      );

      final storageKey = _currentUser!.type == UserType.system
          ? AppConstants.adminUserKey
          : AppConstants.userKey;
      await _safeWrite(
        storageKey,
        jsonEncode(_currentUser!.toJson()),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Refresh current user profile failed: $e');
    }
  }

  Future<void> syncCurrentUserProfile(ProfileData profile) async {
    if (_currentUser == null) return;

    _currentUser = AuthUser(
      email: _currentUser!.email,
      fullName: profile.fullName,
      avatar: profile.avatar,
      token: _currentUser!.token,
      type: _currentUser!.type,
      companyId: _currentUser!.companyId,
      companyName: _currentUser!.companyName,
      employeeId: _currentUser!.employeeId,
      permissions: _currentUser!.permissions,
      deptScopes: _currentUser!.deptScopes,
    );

    final storageKey = _currentUser!.type == UserType.system
        ? AppConstants.adminUserKey
        : AppConstants.userKey;
    await _safeWrite(
      storageKey,
      jsonEncode(_currentUser!.toJson()),
    );
    notifyListeners();
  }

  // =========================================================
  // REFRESH TOKEN
  // =========================================================

  /// Đổi refresh token lấy access token mới. Nhiều lời gọi đồng thời dùng chung một
  /// request (refresh token chỉ dùng được 1 lần vì backend xoay vòng) (F2).
  Future<bool> refreshToken() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  /// Phiên hết hạn và không refresh được: đăng xuất (đang impersonate thì về lại sysadmin) (F3).
  Future<void> handleSessionExpired() async {
    if (isImpersonating) {
      await logoutCompany();
    } else {
      await logout();
    }
  }

  Future<bool> _doRefresh() async {
    final storedRefresh = _currentRefreshToken ?? await _safeRead(
      AppConstants.refreshTokenKey,
    );

    if (storedRefresh == null) {
      return false;
    }

    try {
      final deviceId =
          await DeviceService.instance.getOrCreateDeviceId();

      final res = await _dio.post(
        '/api/v1/auth/refresh',
        data: {
          'refreshToken': storedRefresh,
          'deviceId': deviceId,
        },
        options: Options(headers: _requestHeaders()),
      );

      final token =
          res.data['accessToken'] as String;

      final refreshToken =
          res.data['refreshToken'] as String?;

      final userMap =
          res.data['user'] as Map<String, dynamic>;

      final rawPerms = userMap['permissions'];

      final perms = rawPerms is List
          ? rawPerms
              .map((e) => e.toString())
              .toSet()
          : <String>{};

      _currentUser = AuthUser(
        email: userMap['email'] as String,
        fullName: userMap['fullName'] as String?,
        avatar: userMap['avatar'] as String?,
        token: token,
        type: UserType.company,
        companyId: userMap['companyId'] as int?,
        companyName:
            userMap['companyName'] as String?,
        employeeId:
            userMap['employeeId'] as int?,
        permissions: perms,
      );

      if (_persistSession) {
        await Future.wait([
          _safeWrite(
            AppConstants.tokenKey,
            token,
          ),
          _safeWrite(
            AppConstants.userKey,
            jsonEncode(_currentUser!.toJson()),
          ),
          if (refreshToken != null)
            _safeWrite(
              AppConstants.refreshTokenKey,
              refreshToken,
            ),
        ]);
      }
      _currentRefreshToken = refreshToken;

      notifyListeners();

      return true;
    } catch (_) {
      return false;
    }
  }

  // =========================================================
  // ADMIN LOGIN
  // =========================================================

  Future<AuthUser> adminLogin(
    String email,
    String password,
  ) async {
    final res = await _dio.post(
      '/admin/auth/login',
      data: {
        'email': email,
        'password': password,
      },
      options: Options(headers: _requestHeaders()),
    );

    final token =
        res.data['accessToken'] as String;

    final userMap =
        res.data['user'] as Map<String, dynamic>;

    _currentUser = AuthUser(
      email: userMap['email'] as String,
      fullName: userMap['fullName'] as String?,
      token: token,
      type: UserType.system,
    );

    await Future.wait([
      _safeDelete(AppConstants.tokenKey),
      _safeDelete(AppConstants.userKey),
      _safeDelete(AppConstants.refreshTokenKey),
    ]);
    await Future.wait([
      _safeWrite(AppConstants.adminTokenKey, token),
      _safeWrite(AppConstants.adminUserKey, jsonEncode(_currentUser!.toJson())),
    ]);
    _currentRefreshToken = null;

    return _currentUser!;
  }

  // =========================================================
  // IMPERSONATE COMPANY
  // =========================================================

  Future<AuthUser> impersonateCompany(
    Dio adminDio,
    int companyId,
  ) async {
    final res = await adminDio.post(
      '/companies/$companyId/impersonate',
      options: Options(headers: _requestHeaders(includeToken: true)),
    );

    final token =
        res.data['accessToken'] as String;

    final userMap =
        res.data['user'] as Map<String, dynamic>;

    final rawPerms = userMap['permissions'];

    final perms = rawPerms is List
        ? rawPerms
            .map((e) => e.toString())
            .toSet()
        : <String>{};

    // Giữ lại sysadmin trước khi ghi đè
    _adminUser = _currentUser;

    _currentUser = AuthUser(
      email: userMap['email'] as String,
      fullName: userMap['fullName'] as String?,
      avatar: userMap['avatar'] as String?,
      token: token,
      type: UserType.company,
      companyId: userMap['companyId'] as int?,
      companyName: userMap['companyName'] as String?,
      employeeId: userMap['employeeId'] as int?,
      permissions: perms,
    );

    await Future.wait([
      _safeWrite(AppConstants.tokenKey, token),
      _safeWrite(AppConstants.userKey, jsonEncode(_currentUser!.toJson())),
    ]);
    _currentRefreshToken = null;

    notifyListeners();
    return _currentUser!;
  }

  // =========================================================
  // APPLY PERMISSIONS
  // =========================================================

  void applyPermissions(
    Set<String> newPermissions, {
    Map<String, List<int>>? deptScopes,
  }) {
    if (_currentUser == null) return;

    _currentUser = AuthUser(
      email: _currentUser!.email,
      fullName: _currentUser!.fullName,
      avatar: _currentUser!.avatar,
      token: _currentUser!.token,
      type: _currentUser!.type,
      companyId: _currentUser!.companyId,
      companyName: _currentUser!.companyName,
      employeeId: _currentUser!.employeeId,
      permissions: newPermissions,
      deptScopes:
          deptScopes ?? _currentUser!.deptScopes,
    );

    _safeWrite(
      AppConstants.userKey,
      jsonEncode(_currentUser!.toJson()),
    );

    notifyListeners();
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  /// main.dart gắn NotificationService.deviceToken (tránh import vòng).
  Future<String?> Function()? deviceFcmToken;

  Future<void> logout() async {
    // Thu hồi phiên ở backend (bỏ qua lỗi mạng)
    final refresh = _currentRefreshToken ?? await _safeRead(AppConstants.refreshTokenKey);
    if (refresh != null) {
      try {
        // Gửi kèm FCM token của máy này để backend gỡ — người sau đăng nhập
        // trên cùng máy không nhận nhầm thông báo của người trước (F10).
        final fcmToken = await deviceFcmToken?.call();
        await _dio.post('/api/v1/auth/logout',
            data: {'refreshToken': refresh, if (fcmToken != null) 'fcmToken': fcmToken},
            options: Options(headers: _requestHeaders()));
      } catch (_) {}
    }
    _currentUser = null;
    _currentRefreshToken = null;
    _mustChangePassword = false;

    notifyListeners();

    await Future.wait([
      _safeDelete(_mustChangeKey),
      _safeDelete(AppConstants.tokenKey),
      _safeDelete(AppConstants.adminTokenKey),
      _safeDelete(AppConstants.refreshTokenKey),
      _safeDelete(AppConstants.userKey),
      _safeDelete(AppConstants.adminUserKey),
    ]);
  }

  /// Logout khỏi company session (khi đang impersonate), restore lại admin session.
  Future<void> logoutCompany() async {
    _currentUser = _adminUser; // restore sysadmin
    _adminUser = null;
    _currentRefreshToken = null;

    await Future.wait([
      _safeDelete(AppConstants.tokenKey),
      _safeDelete(AppConstants.refreshTokenKey),
      _safeDelete(AppConstants.userKey),
    ]);

    notifyListeners();
  }

  // =========================================================
  // TOKEN HELPERS
  // =========================================================

  Future<bool> isLoggedIn() async {
    final token = await _safeRead(
      AppConstants.tokenKey,
    );

    return token != null;
  }

  Future<bool> isAdminLoggedIn() async {
    final token = await _safeRead(
      AppConstants.adminTokenKey,
    );

    return token != null;
  }

  Future<String?> getToken() {
    return _safeRead(
      AppConstants.tokenKey,
    );
  }

  Future<String?> getAdminToken() {
    return _safeRead(
      AppConstants.adminTokenKey,
    );
  }
}
