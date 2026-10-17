import '../../core/config/server_config.dart';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/language_service.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import '../../core/navigation/navigator_keys.dart';
import '../../core/config/runtime_host.dart';
import '../repositories/notification_repository.dart';
import 'profile_service.dart';

const _channelId         = 'shift_reminders';
String get _channelName => _l10n().shiftReminderTitle;
const _channelResultId   = 'check_results';
String get _channelResultName => _l10n().uiCheckResultChannelName;

const _actionCheckIn      = 'action_check_in';
const _actionCheckOut     = 'action_check_out';
const _actionOpenCheckIn  = 'action_open_check_in';
const _actionOpenCheckOut = 'action_open_check_out';

const _typeCheckIn  = 'CHECK_IN_REMINDER';
const _typeCheckOut = 'CHECK_OUT_REMINDER';

final _local = FlutterLocalNotificationsPlugin();

AppLocalizations _l10n() => lookupAppLocalizations(LanguageService.instance.locale);

// ── AppNotification ──────────────────────────────────────────────────────────

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? type;
  final DateTime time;
  final bool isRead;
  final Map<String, String> data;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type,
    required this.time,
    this.isRead = false,
    this.data = const {},
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        time: time,
        isRead: isRead ?? this.isRead,
        data: data,
      );

  /// Thông báo từ hộp thư máy chủ (`GET /notifications`).
  factory AppNotification.fromServer(Map<String, dynamic> m) => AppNotification(
        id: '${m['id']}',
        title: m['title'] as String? ?? '',
        body: m['body'] as String? ?? '',
        type: m['type'] as String?,
        time: DateTime.parse(m['createdAt'] as String),
        isRead: m['read'] as bool? ?? false,
        data: ((m['data'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', '$v')),
      );
}

// ── FCM background handler ───────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  await LanguageService.instance.load();
  final type = message.data['type'] as String?;
  if (message.notification != null && type != _typeCheckIn && type != _typeCheckOut) return;
  await _initLocalPlugin();
  await _ensureResultChannel();
  await _showShiftNotification(message);
}

@pragma('vm:entry-point')
void _onBackgroundActionResponse(NotificationResponse response) {
  _handleBackgroundAction(response);
}

Future<void> _handleBackgroundAction(NotificationResponse response) async {
  final actionId = response.actionId;
  if (actionId != _actionCheckIn && actionId != _actionCheckOut) return;
  await LanguageService.instance.load();
  await _initLocalPlugin();
  await _ensureResultChannel();
  await _callCheckInOut(actionId!);
}

// ── Foreground action / tap handler ─────────────────────────────────────────

void _onForegroundResponse(NotificationResponse response) {
  final actionId = response.actionId;

  if (actionId == _actionCheckIn || actionId == _actionCheckOut) {
    _callCheckInOut(actionId!);
    return;
  }

  if (actionId == _actionOpenCheckIn || actionId == _actionOpenCheckOut) {
    NotificationService.instance._pendingAutoAction =
        actionId == _actionOpenCheckIn ? _actionCheckIn : _actionCheckOut;
    _navigateOrPend(AppRoutes.checkInOut);
    return;
  }

  final payload = response.payload;
  if (payload == _actionCheckIn || payload == _actionCheckOut) {
    NotificationService.instance._pendingAutoAction = payload;
  }
  if (payload != null) _navigateOrPend(AppRoutes.checkInOut);
}

void _navigateOrPend(String? route) {
  if (route == null) return;
  final ctx = rootNavigatorKey.currentContext;
  if (ctx != null && ctx.mounted) {
    ctx.go(route);
  } else {
    NotificationService.instance._pendingRoute = route;
  }
}

// ── Core: gọi API check-in / check-out (silent) ──────────────────────────────

Future<void> _callCheckInOut(String actionId) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(AppConstants.tokenKey);
  await ServerConfig.load();
  final host  = ServerConfig.host;

  if (token == null) {
    await _showResultNotif(_l10n().uiNotifSessionExpired);
    return;
  }

  final isCheckIn = actionId == _actionCheckIn;
  final path = isCheckIn
      ? '/api/v1/attendances/self/check-in'   // F1: trước đây sai đường dẫn (/attendance)
      : '/api/v1/attendances/self/check-out';

  try {
    final client = HttpClient();
    final req = await client.postUrl(Uri.parse('$host$path'));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    req.headers.contentType = ContentType.json;
    req.write('{}');
    final res  = await req.close();
    final body = await res.transform(utf8.decoder).join();
    client.close();

    if (res.statusCode == 200 || res.statusCode == 201) {
      await _showResultNotif(
          isCheckIn ? _l10n().uiNotifCheckInSuccess : _l10n().uiNotifCheckOutSuccess);
      return;
    }

    final errorKey = _parseErrorKey(body);
    if (errorKey == 'error.attendance.location_required') {
      await _showOpenAppNotif(isCheckIn);
    } else {
      await _showResultNotif(_parseMsg(body, isCheckIn));
    }
  } catch (_) {
    await _showResultNotif(_l10n().uiNotifConnectionError);
  }
}

Future<void> _showOpenAppNotif(bool isCheckIn) async {
  final openAction = isCheckIn ? _actionOpenCheckIn : _actionOpenCheckOut;
  final s          = _l10n();
  final label      = isCheckIn ? s.uiNotifOpenAndCheckIn : s.uiNotifOpenAndCheckOut;
  final msg        = isCheckIn
      ? s.uiNotifGpsRequiredCheckIn
      : s.uiNotifGpsRequiredCheckOut;

  await _local.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'BossKin',
    msg,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channelResultId,
        _channelResultName,
        importance: Importance.high,
        priority: Priority.high,
        largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
        actions: [
          AndroidNotificationAction(openAction, label, showsUserInterface: true),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    ),
    payload: isCheckIn ? _actionCheckIn : _actionCheckOut,
  );
}

Future<void> _showResultNotif(String message) async {
  await _local.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'BossKin',
    message,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channelResultId,
        _channelResultName,
        importance: Importance.high,
        priority: Priority.high,
        largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    ),
  );
}

Future<void> _showShiftNotification(RemoteMessage message) async {
  final title = message.data['title'] ?? message.notification?.title;
  final body  = message.data['body']  ?? message.notification?.body;
  if (title == null && body == null) return;

  final type    = message.data['type'] as String?;
  final actions = _actionsFor(type);
  final payload = (type == _typeCheckIn || type == _typeCheckOut)
      ? (type == _typeCheckIn ? _actionCheckIn : _actionCheckOut)
      : null;

  NotificationDetails details({required bool withLargeIcon}) => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          largeIcon: withLargeIcon ? const DrawableResourceAndroidBitmap('ic_launcher') : null,
          actions: actions,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
  final id = message.hashCode & 0x7fffffff;
  try {
    await _local.show(id, title, body, details(withLargeIcon: true), payload: payload);
  } catch (e) {
    // Ảnh lớn không đọc được (bản release rút gọn tài nguyên…) → vẫn phải hiện thông báo
    debugPrint('local notification with large icon failed: $e');
    try {
      await _local.show(id, title, body, details(withLargeIcon: false), payload: payload);
    } catch (e2) {
      debugPrint('local notification failed: $e2');
    }
  }
}

List<AndroidNotificationAction> _actionsFor(String? type) {
  if (type == _typeCheckIn) {
    return const [AndroidNotificationAction(
        _actionCheckIn, 'Check-in', showsUserInterface: false)];
  }
  if (type == _typeCheckOut) {
    return const [AndroidNotificationAction(
        _actionCheckOut, 'Check-out', showsUserInterface: false)];
  }
  return const [];
}

Future<void> _initLocalPlugin() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await _local.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
  );
}

Future<void> _ensureResultChannel() async {
  final plugin = _local.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await plugin?.createNotificationChannel(AndroidNotificationChannel(
    _channelResultId, _channelResultName, importance: Importance.high,
  ));
}

String _parseErrorKey(String body) {
  try {
    return (jsonDecode(body) as Map<String, dynamic>)['message'] as String? ?? '';
  } catch (_) {
    return '';
  }
}

String _parseMsg(String body, bool isCheckIn) {
  try {
    final msg = (jsonDecode(body) as Map<String, dynamic>)['message'] as String?;
    if (msg != null && msg.isNotEmpty) return msg;
  } catch (_) {}
  return isCheckIn ? _l10n().uiNotifCheckInFailed : _l10n().uiNotifCheckOutFailed;
}

// ── Service class ────────────────────────────────────────────────────────────

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  late final _fcm = FirebaseMessaging.instance;

  /// main.dart gắn hàm kiểm tra đã đăng nhập (tránh import vòng với AuthService).
  bool Function()? onTokenRefreshWhileSignedIn;
  String? _pendingRoute;
  String? _pendingAutoAction;

  final inbox = ValueNotifier<List<AppNotification>>([]);

  int get unreadCount => inbox.value.where((n) => !n.isRead).length;

  String? consumePendingRoute() {
    final r = _pendingRoute;
    _pendingRoute = null;
    return r;
  }

  String? consumePendingAutoAction() {
    final a = _pendingAutoAction;
    _pendingAutoAction = null;
    return a;
  }

  void _handleFcmTap(RemoteMessage message) {
    final type = message.data['type'] as String?;
    if (type == _typeCheckIn) {
      _pendingAutoAction = _actionCheckIn;
      _navigateOrPend(AppRoutes.checkInOut);
    } else if (type == _typeCheckOut) {
      _pendingAutoAction = _actionCheckOut;
      _navigateOrPend(AppRoutes.checkInOut);
    }
  }

  final _inboxRepo = NotificationRepository();
  bool _inboxLoading = false;

  /// Tải lại hộp thư từ máy chủ (mọi thiết bị của tài khoản thấy cùng danh sách). Lỗi mạng → giữ danh sách cũ.
  Future<void> refreshInbox() async {
    if (_inboxLoading) return;
    _inboxLoading = true;
    try {
      inbox.value = await _inboxRepo.getAll();
    } catch (_) {
      // chưa đăng nhập / mất mạng: để nguyên
    } finally {
      _inboxLoading = false;
    }
  }

  /// Xoá hộp thư trong bộ nhớ khi đăng xuất (không để lộ thông báo của tài khoản trước).
  void clearLocal() => inbox.value = [];

  Future<void> markAllRead() async {
    if (inbox.value.every((n) => n.isRead)) return;
    inbox.value = inbox.value.map((n) => n.copyWith(isRead: true)).toList();
    try {
      await _inboxRepo.markAllRead();
    } catch (_) {}
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    inbox.value = inbox.value.map((x) => x.id == n.id ? x.copyWith(isRead: true) : x).toList();
    try {
      await _inboxRepo.markRead(n.id);
    } catch (_) {}
  }

  Future<void> deleteNotification(AppNotification n) async {
    inbox.value = inbox.value.where((x) => x.id != n.id).toList();
    try {
      await _inboxRepo.delete(n.id);
    } catch (_) {}
  }

  Future<void> clearAll() async {
    inbox.value = [];
    try {
      await _inboxRepo.clear();
    } catch (_) {}
  }

  bool _firebaseReady = false;

  /// Khoá Web Push (VAPID) — chỉ bản web, lấy từ env.js.
  String? _webVapidKey;

  /// Thiết bị / trình duyệt này nhận được thông báo đẩy (Firebase đã sẵn sàng; bản web cần đủ cấu hình FIREBASE_WEB_*).
  bool get available => _firebaseReady;

  /// Ứng dụng có được phép hiện thông báo không; chưa thì hỏi quyền (Android 13+ / iOS).
  /// false = người dùng đã từ chối → phải bật trong cài đặt của điện thoại.
  Future<bool> ensurePermission() async {
    if (!_firebaseReady) return false;
    if (kIsWeb) {
      // Trình duyệt: chỉ hỏi được khi người dùng vừa bấm nút; đã chặn thì phải mở lại trong cài đặt trang
      try {
        final st = await _fcm.requestPermission(alert: true, badge: true, sound: true);
        return st.authorizationStatus == AuthorizationStatus.authorized ||
            st.authorizationStatus == AuthorizationStatus.provisional;
      } catch (_) {
        return false;
      }
    }
    try {
      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        if (await android.areNotificationsEnabled() ?? true) return true;
        return await android.requestNotificationsPermission() ?? false;
      }
      final st = await _fcm.requestPermission(alert: true, badge: true, sound: true);
      return st.authorizationStatus == AuthorizationStatus.authorized ||
          st.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return true; // không hỏi được thì cứ thử gửi
    }
  }

  /// FCM token của thiết bị này (null khi Firebase chưa sẵn sàng, hoặc bản web chưa được cấp quyền thông báo).
  Future<String?> deviceToken() async {
    if (!_firebaseReady) return null;
    try {
      if (kIsWeb) {
        final st = await _fcm.getNotificationSettings();
        if (st.authorizationStatus != AuthorizationStatus.authorized &&
            st.authorizationStatus != AuthorizationStatus.provisional) {
          return null;
        }
        return await _fcm.getToken(vapidKey: _webVapidKey);
      }
      return await _fcm.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Gọi sau khi đăng nhập / khôi phục phiên và khi FCM đổi token (F10):
  /// nếu tài khoản đang bật thông báo thì gắn thông báo về thiết bị hiện tại.
  /// Backend gỡ token này khỏi tài khoản khác (máy dùng chung) và chỉ giữ một thiết bị.
  Future<void> syncDeviceToken({String? token}) async {
    if (!_firebaseReady) return;
    try {
      final t = token ?? await deviceToken();
      if (t == null) return;
      final settings = await ProfileService.instance.getNotificationSettings();
      // Cài đặt lưu theo tài khoản: đăng nhập thêm một máy thì máy đó cũng nhận (nhiều thiết bị / tài khoản)
      final wantsPush = settings.shiftReminderMinutes != null ||
          settings.checkInOutNotifMinutes != null ||
          settings.lateAlert ||
          settings.earlyLeaveAlert;
      if (!wantsPush && !settings.enabled) return;
      await ProfileService.instance.updateNotificationSettings(
        fcmToken: t,
        shiftReminderMinutes: settings.shiftReminderMinutes,
        checkInOutNotifMinutes: settings.checkInOutNotifMinutes,
      );
    } catch (_) {
      // chưa đăng nhập / mất mạng: lần đăng nhập sau sẽ đồng bộ lại
    }
  }

  Future<void> initialize() async {
    if (kIsWeb) {
      await _initializeWeb();
      return;
    }

    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (_) {
      return;
    }

    _fcm.onTokenRefresh.listen((t) {
      if (onTokenRefreshWhileSignedIn?.call() ?? false) syncDeviceToken(token: t);
    });

    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    if (Platform.isAndroid || Platform.isIOS) {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundActionResponse,
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(AndroidNotificationChannel(
      _channelId, _channelName, importance: Importance.high,
    ));
    await androidPlugin?.createNotificationChannel(AndroidNotificationChannel(
      _channelResultId, _channelResultName, importance: Importance.high,
    ));

    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final response = launch!.notificationResponse;
      final payload  = response?.payload;
      final actionId = response?.actionId;
      if (actionId == _actionOpenCheckIn || actionId == _actionOpenCheckOut) {
        _pendingAutoAction =
            actionId == _actionOpenCheckIn ? _actionCheckIn : _actionCheckOut;
        _pendingRoute = AppRoutes.checkInOut;
      } else if (payload == _actionCheckIn || payload == _actionCheckOut) {
        _pendingAutoAction = payload;
        _pendingRoute = AppRoutes.checkInOut;
      } else if (payload != null) {
        _pendingRoute = payload;
      }
    }

    FirebaseMessaging.onMessage.listen((msg) {
      _showShiftNotification(msg);
      refreshInbox();   // thông báo đã được máy chủ lưu — chỉ cần tải lại
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleFcmTap);

    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleFcmTap(initial);
  }

  /// Bản web: Firebase khởi tạo bằng cấu hình trong env.js; thông báo do web/firebase-messaging-sw.js hiện (cả khi
  /// trang đang mở — xem lý do trong file đó), ở đây chỉ tải lại hộp thông báo từ máy chủ. Không xin quyền ở đây — trình duyệt chỉ cho xin
  /// khi người dùng bấm nút (Lưu cài đặt thông báo / Gửi thông báo thử).
  Future<void> _initializeWeb() async {
    final cfg = runtimeFirebaseConfig();
    if (cfg == null) return;
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: cfg['apiKey']!,
          appId: cfg['appId']!,
          messagingSenderId: cfg['messagingSenderId']!,
          projectId: cfg['projectId']!,
        ),
      );
      if (!await _fcm.isSupported()) return;
      _webVapidKey = cfg['vapidKey'];
      _firebaseReady = true;
    } catch (_) {
      return;
    }

    _fcm.onTokenRefresh.listen((t) {
      if (onTokenRefreshWhileSignedIn?.call() ?? false) syncDeviceToken(token: t);
    });
    FirebaseMessaging.onMessage.listen((_) => refreshInbox());
  }

  /// Gắn thiết bị này vào tài khoản (một tài khoản có nhiều thiết bị) và lưu cài đặt thông báo.
  Future<void> registerToken({
    required int? shiftReminderMinutes,
    required int? checkInOutNotifMinutes,
    bool? lateAlert,
    bool? earlyLeaveAlert,
  }) async {
    final token = await deviceToken();
    await ProfileService.instance.updateNotificationSettings(
      fcmToken: token,
      shiftReminderMinutes: shiftReminderMinutes,
      checkInOutNotifMinutes: checkInOutNotifMinutes,
      lateAlert: lateAlert,
      earlyLeaveAlert: earlyLeaveAlert,
    );
  }

  /// Lưu cài đặt không gắn thiết bị (cũng dùng khi tắt hết nhắc).
  Future<void> saveSettingsOnly({
    required int? shiftReminderMinutes,
    required int? checkInOutNotifMinutes,
    bool? lateAlert,
    bool? earlyLeaveAlert,
  }) =>
      ProfileService.instance.updateNotificationSettings(
        fcmToken: null,
        shiftReminderMinutes: shiftReminderMinutes,
        checkInOutNotifMinutes: checkInOutNotifMinutes,
        lateAlert: lateAlert,
        earlyLeaveAlert: earlyLeaveAlert,
      );
}
