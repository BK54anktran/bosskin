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
