#!/bin/sh
# Chuẩn hoá biến kết nối CSDL rồi chạy app.
# 1. Nền tảng cấp CSDL kèm website (Vibe Host tiêm MYSQL_HOST / MYSQL_PORT / MYSQL_DATABASE / MYSQL_USER / MYSQL_PASSWORD):
#    dùng luôn CSDL đó — bỏ qua DB_URL / DB_USERNAME / DB_PASSWORD đặt tay.
# 2. Không có MYSQL_HOST: dùng DB_URL; dạng mysql://… được thêm tiền tố jdbc: (có nền tảng chỉ nhận scheme://).
set -e
if [ -n "$MYSQL_HOST" ] && [ -n "$MYSQL_DATABASE" ]; then
  export DB_URL="jdbc:mysql://${MYSQL_HOST}:${MYSQL_PORT:-3306}/${MYSQL_DATABASE}?sslMode=PREFERRED&allowPublicKeyRetrieval=true&serverTimezone=Asia/Ho_Chi_Minh&characterEncoding=UTF-8"
  export DB_USERNAME="$MYSQL_USER"
  export DB_PASSWORD="$MYSQL_PASSWORD"
  echo "entrypoint: dùng CSDL nền tảng cấp ${MYSQL_HOST}:${MYSQL_PORT:-3306}/${MYSQL_DATABASE}"
else
  case "$DB_URL" in mysql://*) export DB_URL="jdbc:$DB_URL" ;; esac
fi
exec java $JAVA_OPTS -jar app.jar
