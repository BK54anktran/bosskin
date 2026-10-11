// Bản Docker: Nginx ghi đè file này lúc khởi động từ biến môi trường (frontend/docker/40-env.sh).
// Dùng `self` (không phải `window`) vì firebase-messaging-sw.js cũng nạp file này.
self.BOSSKIN_API_HOST = self.BOSSKIN_API_HOST || '';
// Thông báo đẩy trên web: để trống = tắt. Giá trị lấy ở Firebase Console → Project settings (Web app + Web Push certificates).
self.BOSSKIN_FIREBASE = self.BOSSKIN_FIREBASE || { apiKey: '', appId: '', messagingSenderId: '', projectId: '', vapidKey: '' };
