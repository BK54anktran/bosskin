import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Kho lưu khoá dùng chung (token đăng nhập, mã thiết bị).
///
/// Android: `resetOnError` — dữ liệu cũ không giải mã được (cài lại app, Android khôi phục bản sao lưu được mã hoá
/// bằng khoá của lần cài trước…) thì xoá và ghi lại, thay vì mọi lần đọc / ghi đều lỗi khiến app không lưu được
/// phiên đăng nhập. Hai file của kho này cũng bị loại khỏi sao lưu (android/app/src/main/res/xml/*_rules.xml).
const appSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: true),
  webOptions: WebOptions(
    dbName: 'bosskin',
    publicKey: 'bosskin_key',
  ),
);
