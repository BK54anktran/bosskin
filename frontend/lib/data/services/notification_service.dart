import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/navigation/navigator_keys.dart';
import 'profile_service.dart';

const _channelId         = 'shift_reminders';
const _channelName       = 'Nhắc nhở ca làm';
const _channelResultId   = 'check_results';
const _channelResultName = 'Kết quả check-in/out';

const _actionCheckIn      = 'action_check_in';
const _actionCheckOut     = 'action_check_out';
const _actionOpenCheckIn  = 'action_open_check_in';
const _actionOpenCheckOut = 'action_open_check_out';

const _typeCheckIn  = 'CHECK_IN_REMINDER';
const _typeCheckOut = 'CHECK_OUT_REMINDER';

final _local = FlutterLocalNotificationsPlugin();

// ── AppNotification ──────────────────────────────────────────────────────────

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? type;
  final DateTime time;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type,
    required this.time,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        time: time,
        isRead: isRead ?? this.isRead,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'time': time.toIso8601String(),
        'isRead': isRead,
      };

  factory AppNotification.fromJson(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String,
        title: m['title'] as String,
        body: m['body'] as String? ?? '',
        type: m['type'] as String?,
        time: DateTime.parse(m['time'] as String),
        isRead: m['isRead'] as bool? ?? false,
      );
}

// ── FCM background handler ───────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  final type = message.data['type'] as String?;
  if (message.notification != null && type != _typeCheckIn && type != _typeCheckOut) return;
  await _initLocalPlugin();
  await _ensureResultChannel();
  await _showShiftNotification(message);
  await _saveNotificationToPrefs(message);
}

Future<void> _saveNotificationToPrefs(RemoteMessage message) async {
  try {
    final title = message.data['title'] as String? ?? message.notification?.title;
    final body  = message.data['body']  as String? ?? message.notification?.body;
    if (title == null) return;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('notification_inbox') ?? [];

    final n = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body ?? '',
      type: message.data['type'] as String?,
      time: DateTime.now(),
    );

    final updated = [jsonEncode(n.toJson()), ...stored].take(50).toList();
    await prefs.setStringList('notification_inbox', updated);
  } catch (_) {}
}

@pragma('vm:entry-point')
void _onBackgroundActionResponse(NotificationResponse response) {
  _handleBackgroundAction(response);
}

Future<void> _handleBackgroundAction(NotificationResponse response) async {
  final actionId = response.actionId;
  if (actionId != _actionCheckIn && actionId != _actionCheckOut) return;
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
  final host  = prefs.getString('server_host') ?? 'http://192.168.0.12:8080';

  if (token == null) {
    await _showResultNotif('Phiên đăng nhập hết hạn — vui lòng mở app');
    return;
  }

  final isCheckIn = actionId == _actionCheckIn;
  final path = isCheckIn
      ? '/api/v1/attendance/self/check-in'
      : '/api/v1/attendance/self/check-out';

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
          isCheckIn ? 'Check-in thành công!' : 'Check-out thành công!');
      return;
    }

    final errorKey = _parseErrorKey(body);
    if (errorKey == 'error.attendance.location_required') {
      await _showOpenAppNotif(isCheckIn);
    } else {
      await _showResultNotif(_parseMsg(body, isCheckIn));
    }
  } catch (_) {
    await _showResultNotif('Lỗi kết nối — vui lòng kiểm tra trong app');
  }
}

Future<void> _showOpenAppNotif(bool isCheckIn) async {
  final openAction = isCheckIn ? _actionOpenCheckIn : _actionOpenCheckOut;
  final label      = isCheckIn ? 'Mở & Check-in' : 'Mở & Check-out';
  final msg        = isCheckIn
      ? 'Công ty yêu cầu GPS — nhấn để check-in ngay khi mở app'
      : 'Công ty yêu cầu GPS — nhấn để check-out ngay khi mở app';

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
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelResultId,
        _channelResultName,
        importance: Importance.high,
        priority: Priority.high,
        largeIcon: DrawableResourceAndroidBitmap('ic_launcher'),
      ),
      iOS: DarwinNotificationDetails(
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

  await _local.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
        actions: actions,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: payload,
  );
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
  await plugin?.createNotificationChannel(const AndroidNotificationChannel(
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
  return isCheckIn ? 'Không thể check-in' : 'Không thể check-out';
}

// ── Service class ────────────────────────────────────────────────────────────

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  late final _fcm = FirebaseMessaging.instance;
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

  void _addToInbox(String title, String body, String? type) {
    final n = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      time: DateTime.now(),
    );
    inbox.value = [n, ...inbox.value].take(50).toList();
    _saveInbox();
  }

  Future<void> _saveInbox() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'notification_inbox',
        inbox.value.map((n) => jsonEncode(n.toJson())).toList(),
      );
    } catch (_) {}
  }

  Future<void> _loadInbox() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('notification_inbox') ?? [];
      inbox.value = stored
          .map((s) => AppNotification.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  void markAllRead() {
    if (inbox.value.every((n) => n.isRead)) return;
    inbox.value = inbox.value.map((n) => n.copyWith(isRead: true)).toList();
    _saveInbox();
  }

  Future<void> initialize() async {
    if (kIsWeb) return;

    try {
      await Firebase.initializeApp();
    } catch (_) {
      return;
    }

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
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId, _channelName, importance: Importance.high,
    ));
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
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

    await _loadInbox();

    FirebaseMessaging.onMessage.listen((msg) {
      _showShiftNotification(msg);
      final title = msg.data['title'] as String? ?? msg.notification?.title;
      final body  = msg.data['body']  as String? ?? msg.notification?.body;
      if (title != null) _addToInbox(title, body ?? '', msg.data['type'] as String?);
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleFcmTap);

    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleFcmTap(initial);
  }

  Future<void> registerToken({
    required int? shiftReminderMinutes,
    required int? checkInOutNotifMinutes,
  }) async {
    String? token;
    if (!kIsWeb) token = await _fcm.getToken();
    await ProfileService.instance.updateNotificationSettings(
      fcmToken: token,
      shiftReminderMinutes: shiftReminderMinutes,
      checkInOutNotifMinutes: checkInOutNotifMinutes,
    );
  }

  Future<void> disableNotifications() async {
    await ProfileService.instance.updateNotificationSettings(
      fcmToken: null,
      shiftReminderMinutes: null,
      checkInOutNotifMinutes: null,
    );
  }
}
