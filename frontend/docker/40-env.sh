#!/bin/sh
# Chạy khi container Nginx khởi động: ghi cấu hình lúc chạy vào env.js để bản web đọc (không cần build lại).
#   API_HOST                 địa chỉ backend
#   FIREBASE_WEB_API_KEY, FIREBASE_WEB_APP_ID, FIREBASE_WEB_SENDER_ID, FIREBASE_WEB_PROJECT_ID, FIREBASE_WEB_VAPID_KEY
#                            thông báo đẩy trên web (đủ cả 5 mới bật). Đây là cấu hình công khai của Firebase, không phải bí mật.
set -e
q() { printf '%s' "$1" | sed "s/['\\\\]//g"; }
{
  printf "self.BOSSKIN_API_HOST = '%s';\n" "$(q "${API_HOST:-}")"
  printf "self.BOSSKIN_FIREBASE = { apiKey: '%s', appId: '%s', messagingSenderId: '%s', projectId: '%s', vapidKey: '%s' };\n" \
    "$(q "${FIREBASE_WEB_API_KEY:-}")" "$(q "${FIREBASE_WEB_APP_ID:-}")" "$(q "${FIREBASE_WEB_SENDER_ID:-}")" \
    "$(q "${FIREBASE_WEB_PROJECT_ID:-}")" "$(q "${FIREBASE_WEB_VAPID_KEY:-}")"
} > /usr/share/nginx/html/env.js
echo "env.js: API_HOST=${API_HOST:-<trống — dùng API_HOST lúc build hoặc localhost>} · thông báo web: $([ -n "${FIREBASE_WEB_VAPID_KEY:-}" ] && echo bật || echo tắt)"
