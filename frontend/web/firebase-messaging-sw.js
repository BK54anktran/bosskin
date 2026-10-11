// Service worker nhận thông báo đẩy (FCM) cho bản web khi trang không mở / không ở phía trước.
// Firebase đăng ký file này ở phạm vi riêng (/firebase-cloud-messaging-push-scope), không đụng service worker của Flutter.
// Cấu hình đọc từ env.js (cùng nguồn với trang) — thiếu thì không làm gì.
importScripts('env.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

(function () {
  var c = self.BOSSKIN_FIREBASE || {};
  if (!c.apiKey || !c.appId || !c.messagingSenderId || !c.projectId) return;
  firebase.initializeApp({ apiKey: c.apiKey, appId: c.appId, messagingSenderId: c.messagingSenderId, projectId: c.projectId });
  // Backend gửi tin dạng data (title / body / type) — tự hiện thông báo
  firebase.messaging().onBackgroundMessage(function (payload) {
    var d = payload.data || {};
    var n = payload.notification || {};
    var title = d.title || n.title;
    if (!title) return;
    return self.registration.showNotification(title, {
      body: d.body || n.body || '',
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      tag: d.type || undefined,
      data: { type: d.type || '' },
    });
  });
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
