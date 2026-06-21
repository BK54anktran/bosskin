import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'profile_service.dart';

const _channelId = 'shift_reminders';
const _channelName = 'Nhắc nhở ca làm';

final _local = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  _showNotification(message);
}

void _showNotification(RemoteMessage message) {
  final title = message.data['title'] ?? message.notification?.title;
  final body  = message.data['body']  ?? message.notification?.body;
  if (title == null && body == null) return;

  _local.show(
    message.hashCode,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      ),
    ),
  );
}

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  late final _fcm = FirebaseMessaging.instance;

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
    await _local.initialize(
      const InitializationSettings(android: androidSettings),
    );

    FirebaseMessaging.onMessage.listen(_showNotification);
  }

  Future<void> registerToken(int reminderMinutes) async {
    String? token;
    if (!kIsWeb) token = await _fcm.getToken();
    await ProfileService.instance.updateNotificationSettings(
      fcmToken: token,
      shiftReminderMinutes: reminderMinutes,
    );
  }

  Future<void> disableNotifications() async {
    await ProfileService.instance.updateNotificationSettings(
      fcmToken: null,
      shiftReminderMinutes: null,
    );
  }
}
