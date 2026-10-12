// Service worker nhận thông báo đẩy (FCM) cho bản web — cả khi trang đang mở lẫn khi đóng / chạy nền.
// Firebase đăng ký file này ở phạm vi riêng (/firebase-cloud-messaging-push-scope), không đụng service worker của Flutter.
// Cấu hình đọc từ env.js (cùng nguồn với trang) — thiếu thì không làm gì.
importScripts('env.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

// Bản mới thay ngay bản cũ (không chờ đóng hết tab)
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (event) { event.waitUntil(self.clients.claim()); });

// Backend gửi tin dạng data (title / body / type) — LUÔN tự hiện thông báo ngay trong sự kiện push.
// Không giao cho trang hiện khi trang đang mở: Safari (iPhone) coi lần đẩy không hiện thông báo trong sự kiện push
// là "đẩy im lặng", đủ 3 lần thì huỷ đăng ký nhận thông báo → các lần nhắc sau không tới nữa.
self.addEventListener('push', function (event) {
  var payload = {};
  try { payload = event.data ? event.data.json() : {}; } catch (e) { return; }
  var d = payload.data || {};
  var n = payload.notification || {};
  var title = d.title || n.title;
  if (!title) return;
  event.waitUntil(self.registration.showNotification(title, {
    body: d.body || n.body || '',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    tag: d.type || undefined,
    data: { type: d.type || '' },
  }));
});

(function () {
  var c = self.BOSSKIN_FIREBASE || {};
  if (!c.apiKey || !c.appId || !c.messagingSenderId || !c.projectId) return;
  firebase.initializeApp({ apiKey: c.apiKey, appId: c.appId, messagingSenderId: c.messagingSenderId, projectId: c.projectId });
  // Vẫn khởi tạo Firebase Messaging: nó chuyển tin cho trang đang mở (onMessage → hộp thông báo trong app).
  // Không đặt onBackgroundMessage — thông báo đã hiện ở trên.
  firebase.messaging();
})();

// Bấm thông báo: đưa tab BossKin đang mở ra trước, chưa có thì mở mới
self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var type = (event.notification.data || {}).type;
  var path = (type === 'CHECK_IN_REMINDER' || type === 'CHECK_OUT_REMINDER') ? 'check-in-out' : '';
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
    for (var i = 0; i < list.length; i++) { if ('focus' in list[i]) return list[i].focus(); }
    return self.clients.openWindow(new URL(path, self.registration.scope.replace('firebase-cloud-messaging-push-scope', '')).href);
  }));
});
