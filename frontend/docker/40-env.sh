#!/bin/sh
# Chạy khi container Nginx khởi động: ghi địa chỉ backend vào env.js để bản web đọc lúc chạy (không cần build lại).
set -e
printf "window.BOSSKIN_API_HOST = '%s';\n" "$(printf '%s' "${API_HOST:-}" | sed "s/'//g")" > /usr/share/nginx/html/env.js
echo "env.js: API_HOST=${API_HOST:-<trống — dùng API_HOST lúc build hoặc localhost>}"
