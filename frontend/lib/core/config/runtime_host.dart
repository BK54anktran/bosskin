/// Địa chỉ backend đọc lúc chạy (bản web: `window.BOSSKIN_API_HOST` do `web/env.js` đặt). Mobile / test: không có.
export 'runtime_host_stub.dart' if (dart.library.js_interop) 'runtime_host_web.dart';
