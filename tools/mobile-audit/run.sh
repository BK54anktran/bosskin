#!/usr/bin/env bash
# Bật MySQL + backend + Flutter web (cổng 3000) với dữ liệu "Nội thất An Phát" rồi quét giao diện điện thoại 390x844.
# Dùng:  tools/mobile-audit/run.sh up      # bật mọi thứ (lần đầu: tạo DB, build jar, seed)
#        tools/mobile-audit/run.sh crawl   # quét các màn, ghi report-*.json + ảnh vào $OUT (mặc định /tmp/mobile-audit)
#        tools/mobile-audit/run.sh reload  # hot reload sau khi sửa Dart (R)
# Ghi chú: KHÔNG dùng pkill -f / pgrep -f (tự khớp dòng lệnh của shell).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
W=/tmp/mobile-audit; mkdir -p "$W"; export OUT="${OUT:-$W/shots}"; mkdir -p "$OUT"
DBURL='jdbc:mysql://127.0.0.1:3306/bosskin?useSSL=false&serverTimezone=Asia/Ho_Chi_Minh&allowPublicKeyRetrieval=true'
FL=/opt/fl/flutter/bin/flutter

up() {
  # MySQL 8
  if ! mysqladmin --no-defaults -uroot -S /tmp/my8.sock ping >/dev/null 2>&1; then
    [ -d /var/lib/my8/mysql ] || mysqld --no-defaults --initialize-insecure --user=mysql --datadir=/var/lib/my8
    (nohup mysqld --no-defaults --user=mysql --datadir=/var/lib/my8 --socket=/tmp/my8.sock --port=3306 --bind-address=127.0.0.1 > $W/mysql.log 2>&1 &)
    for i in $(seq 1 30); do mysqladmin --no-defaults -uroot -S /tmp/my8.sock ping >/dev/null 2>&1 && break; sleep 2; done
  fi
  mysql --no-defaults -uroot -S /tmp/my8.sock -e "CREATE DATABASE IF NOT EXISTS bosskin CHARACTER SET utf8mb4;" 
  # Backend (Flyway chạy khi khởi động lần đầu)
  [ -f "$ROOT/backend/target/bosskin-1.0.0.jar" ] || (cd "$ROOT/backend" && mvn -q -DskipTests package)
  (cd $W && DB_URL="$DBURL" JWT_SECRET="test-secret-for-local-audit-0123456789abcdefghijklmnop" REQUIRE_SYSADMIN_2FA=false \
     BOOTSTRAP_SYSADMIN_EMAIL=sys@bosskin.local BOOTSTRAP_SYSADMIN_PASSWORD='SysAudit2026x' APP_DOCUMENTS_STORAGE=local \
     nohup java -jar "$ROOT/backend/target/bosskin-1.0.0.jar" > $W/backend.log 2>&1 &)
  for i in $(seq 1 60); do curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080/actuator/health | grep -q 200 && break; sleep 3; done
  # Dữ liệu mẫu (chỉ khi chưa có công ty An Phát). Tài khoản: admin@anphat.local / AnPhat2026demo, nhân viên kd@anphat.local
  if ! curl -s -X POST http://127.0.0.1:8080/api/v1/auth/login -H 'Content-Type: application/json' \
       -d '{"email":"admin@anphat.local","password":"AnPhat2026demo"}' | grep -q accessToken; then
    (cd "$ROOT/landing/video" && /tmp/ev/bin/python seed_demo.py http://127.0.0.1:8080 sys@bosskin.local 'SysAudit2026x')
  fi
  # Flutter web (debug, có hot reload qua fifo)
  rm -f $W/fl.in; mkfifo $W/fl.in
  (cd "$ROOT/frontend" && nohup bash -c "exec 3<>$W/fl.in; $FL run -d web-server --web-port=3000 --web-hostname=127.0.0.1 --dart-define=API_HOST=http://127.0.0.1:8080 <&3" > $W/fl.log 2>&1 &)
  for i in $(seq 1 90); do curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/ | grep -q 200 && break; sleep 5; done
  echo "Sẵn sàng: http://127.0.0.1:3000 (log trong $W)"
}

crawl() {
  cd "$ROOT/tools/mobile-audit"
  # Muốn thấy dòng RenderFlex overflowed kèm vị trí: thêm TẠM vào frontend/lib/main.dart
  #   FlutterError.presentError = (d) => FlutterError.dumpErrorToConsole(d, forceReport: true);   // KHÔNG commit
  NODE_PATH=$(npm root -g) TAG="${TAG:-run}" node crawl.js
  node -e "const r=require('./report-${TAG:-run}.json');const m={};for(const x of r)for(const i of x.issues||[]){const o=(i.match(/overflowed by [\d.]+ pixels on the \w+/)||[])[0];const l=(i.match(/lib\/[^ ]+dart:\d+:\d+/)||[])[0];if(o)(m[o+' @ '+l]=1)}console.log(Object.keys(m).join('\n')||'Không có lỗi tràn layout')"
}

case "${1:-}" in
  up) up ;;
  crawl) crawl ;;
  reload) echo R > $W/fl.in ;;
  *) echo "Dùng: $0 up|crawl|reload"; exit 1 ;;
esac
