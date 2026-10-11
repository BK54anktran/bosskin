#!/bin/sh
# Chuẩn hoá biến kết nối CSDL rồi chạy app.
# 1. Có DB_URL: dùng nó; dạng mysql://… được thêm tiền tố jdbc: (có nền tảng chỉ nhận scheme://).
# 2. Không có DB_URL nhưng nền tảng cấp CSDL kèm website (Vibe Host tiêm MYSQL_HOST / MYSQL_PORT / MYSQL_DATABASE /
#    MYSQL_USER / MYSQL_PASSWORD): dùng CSDL đó.
set -e
if [ -n "$DB_URL" ]; then
  case "$DB_URL" in mysql://*) export DB_URL="jdbc:$DB_URL" ;; esac
  # Vibe Host tiêm DB_URL + MYSQL_USER nhưng không có DB_USERNAME
  [ -n "$DB_USERNAME" ] || [ -z "$MYSQL_USER" ] || export DB_USERNAME="$MYSQL_USER"
elif [ -n "$MYSQL_HOST" ] && [ -n "$MYSQL_DATABASE" ]; then
  export DB_URL="jdbc:mysql://${MYSQL_HOST}:${MYSQL_PORT:-3306}/${MYSQL_DATABASE}?sslMode=PREFERRED&allowPublicKeyRetrieval=true&serverTimezone=Asia/Ho_Chi_Minh&characterEncoding=UTF-8"
  export DB_USERNAME="$MYSQL_USER"
  export DB_PASSWORD="$MYSQL_PASSWORD"
  echo "entrypoint: dùng CSDL nền tảng cấp ${MYSQL_HOST}:${MYSQL_PORT:-3306}/${MYSQL_DATABASE}"
fi
exec java $JAVA_OPTS -jar app.jar
