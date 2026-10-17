import 'package:dio/dio.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart' show AppNotification;

/// Hộp thư thông báo ở máy chủ — mọi thiết bị của tài khoản đọc cùng một danh sách.
class NotificationRepository {
  Dio get _dio => ApiService.instance.dio;

  Future<List<AppNotification>> getAll({int limit = 50}) async {
    final res = await _dio.get('/notifications', queryParameters: {'limit': limit});
    return (res.data as List)
        .map((e) => AppNotification.fromServer(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> unreadCount() async {
    final res = await _dio.get('/notifications/unread-count');
    return ((res.data as Map<String, dynamic>)['count'] as num).toInt();
  }

  Future<void> markRead(String id) => _dio.post('/notifications/$id/read');

  Future<void> markAllRead() => _dio.post('/notifications/read-all');

  Future<void> delete(String id) => _dio.delete('/notifications/$id');

  Future<void> clear() => _dio.delete('/notifications');
}
