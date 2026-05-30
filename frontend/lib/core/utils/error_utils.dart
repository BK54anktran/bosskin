import 'package:dio/dio.dart';

import '../localization/language_service.dart';

String serverMsg(dynamic e) {
  final en = LanguageService.instance.isEnglish;

  if (e is DioException) {
    final status = e.response?.statusCode;
    final code = status ?? 0;
    final data = e.response?.data;

    String? msg;
    if (data is Map) {
      msg = (data['message'] as String?)?.trim();
      if (msg == null || msg.isEmpty) {
        msg = (data['error'] as String?)?.trim();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      msg = data.trim();
    }

    if (msg != null && msg.isNotEmpty) return msg;

    return switch (code) {
      400 => en ? 'Invalid data' : 'Dữ liệu không hợp lệ',
      401 => en
          ? 'Session expired, please sign in again'
          : 'Phiên đăng nhập hết hạn, vui lòng đăng nhập lại',
      403 => en
          ? 'You do not have permission to perform this action'
          : 'Không có quyền thực hiện thao tác này',
      404 => en ? 'Data not found' : 'Không tìm thấy dữ liệu',
      409 => en
          ? 'Data conflict, please check again'
          : 'Xung đột dữ liệu, vui lòng kiểm tra lại',
      500 => en ? 'Server error, please try again later' : 'Lỗi server, vui lòng thử lại sau',
      _ => en ? 'Unknown error (code $code)' : 'Lỗi không xác định (mã $code)',
    };
  }

  return en
      ? 'Unable to connect to server, please check your network'
      : 'Không thể kết nối server, kiểm tra kết nối mạng';
}
