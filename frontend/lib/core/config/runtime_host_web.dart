import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// `env.js` (Nginx sinh lúc container khởi động từ biến môi trường API_HOST) đặt `window.BOSSKIN_API_HOST`.
String? runtimeApiHost() {
  final v = globalContext.getProperty<JSAny?>('BOSSKIN_API_HOST'.toJS);
  if (v == null || !v.isA<JSString>()) return null;
  final s = (v as JSString).toDart.trim();
  if (s.isEmpty) return null;
  return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}
