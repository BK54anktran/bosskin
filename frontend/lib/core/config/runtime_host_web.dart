import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// `env.js` (Nginx sinh lúc container khởi động từ biến môi trường API_HOST) đặt `window.BOSSKIN_API_HOST`.
String? runtimeApiHost() {
  try {
    final v = globalContext.getProperty<JSString?>('BOSSKIN_API_HOST'.toJS);
    final s = v?.toDart.trim() ?? '';
    if (s.isEmpty) return null;
    return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
  } catch (_) {
    return null; // giá trị không phải chuỗi
  }
}

/// `env.js` đặt `BOSSKIN_FIREBASE` = {apiKey, appId, messagingSenderId, projectId, vapidKey} (từ biến môi trường
/// FIREBASE_WEB_* của container Nginx). Thiếu một trong các giá trị → null → bản web không bật thông báo đẩy.
Map<String, String>? runtimeFirebaseConfig() {
  try {
    final o = globalContext.getProperty<JSObject?>('BOSSKIN_FIREBASE'.toJS);
    if (o == null) return null;
    final out = <String, String>{};
    for (final k in const ['apiKey', 'appId', 'messagingSenderId', 'projectId', 'vapidKey']) {
      final v = o.getProperty<JSString?>(k.toJS)?.toDart.trim() ?? '';
      if (v.isEmpty) return null;
      out[k] = v;
    }
    return out;
  } catch (_) {
    return null;
  }
}

/// Trang đang mở thì FCM không tự hiện thông báo → nhờ service worker hiện (hàm `bosskinNotify` trong index.html).
void showWebNotification(String title, String body) {
  try {
    globalContext.callMethod('bosskinNotify'.toJS, title.toJS, body.toJS);
  } catch (_) {}
}
