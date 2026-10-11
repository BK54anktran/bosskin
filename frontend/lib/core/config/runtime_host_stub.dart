String? runtimeApiHost() => null;

/// Cấu hình Firebase cho bản web (mobile lấy từ google-services.json / GoogleService-Info.plist).
Map<String, String>? runtimeFirebaseConfig() => null;

/// Hiện thông báo của trình duyệt khi trang đang mở (chỉ bản web).
void showWebNotification(String title, String body) {}
