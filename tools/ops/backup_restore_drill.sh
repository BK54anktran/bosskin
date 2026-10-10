#!/usr/bin/env bash
# Diễn tập sao lưu / khôi phục DB BossKin (runbook mục 5) — chạy mỗi tháng và trước go-live.
#
#   1. mysqldump DB nguồn → file .sql.gz (chính là bản sao lưu hằng tuần)
#   2. Khôi phục vào DB tạm MỚI tên *_restore_test (không bao giờ ghi vào DB nguồn)
#   3. So từng bảng: số dòng nguồn = bản khôi phục; lịch sử Flyway giống hệt
#   4. In báo cáo; mã thoát ≠ 0 nếu lệch
#
# Biến môi trường: DB_HOST (localhost), DB_PORT (3306), DB_USER (root), DB_PASS, SRC_DB (bosskin),
#                  DST_DB (${SRC_DB}_restore_test), OUT_DIR (.)
# Lưu ý: chỉ đọc DB nguồn (--single-transaction). DB đích phải CHƯA tồn tại; script không xoá DB nào.
# Dùng xong, tự xoá DB tạm bằng tay nếu muốn: DROP DATABASE <DST_DB>; (chỉ DB *_restore_test).
set -euo pipefail

DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-3306}
DB_USER=${DB_USER:-root}
SRC_DB=${SRC_DB:-bosskin}
DST_DB=${DST_DB:-${SRC_DB}_restore_test}
OUT_DIR=${OUT_DIR:-.}
MYSQL_PWD=${DB_PASS:-${MYSQL_PWD:-}}
export MYSQL_PWD

case "$DST_DB" in
  *_restore_test) ;;
  *) echo "DST_DB phải kết thúc bằng _restore_test (đang là '$DST_DB')" >&2; exit 2 ;;
esac
[ "$DST_DB" != "$SRC_DB" ] || { echo "DST_DB trùng SRC_DB" >&2; exit 2; }

conn=(-h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER")
q() { mysql "${conn[@]}" -N -B -e "$1"; }

if [ -n "$(q "SHOW DATABASES LIKE '$DST_DB'")" ]; then
  echo "DB đích '$DST_DB' đã có — đổi DST_DB hoặc tự xoá DB tạm đó trước (script không xoá)." >&2
  exit 2
fi

stamp=$(date +%Y%m%d-%H%M%S)
dump="$OUT_DIR/${SRC_DB}-${stamp}.sql.gz"
t0=$(date +%s)
echo "1/4 Sao lưu $SRC_DB → $dump"
mysqldump "${conn[@]}" --single-transaction --routines --set-gtid-purged=OFF --no-tablespaces "$SRC_DB" | gzip > "$dump"
t1=$(date +%s)

echo "2/4 Khôi phục vào $DST_DB"
q "CREATE DATABASE \`$DST_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
gunzip -c "$dump" | mysql "${conn[@]}" "$DST_DB"
t2=$(date +%s)

echo "3/4 Đối chiếu số dòng từng bảng"
tables=$(q "SELECT table_name FROM information_schema.tables WHERE table_schema='$SRC_DB' AND table_type='BASE TABLE' ORDER BY table_name")
diff=0; n=0; rows=0
for t in $tables; do
  a=$(q "SELECT COUNT(*) FROM \`$SRC_DB\`.\`$t\`")
  b=$(q "SELECT COUNT(*) FROM \`$DST_DB\`.\`$t\`" 2>/dev/null || echo "THIẾU")
  n=$((n+1)); rows=$((rows+a))
  if [ "$a" != "$b" ]; then echo "  LỆCH $t: nguồn $a, khôi phục $b"; diff=$((diff+1)); fi
done

echo "4/4 Lịch sử Flyway"
fa=$(q "SELECT CONCAT(COUNT(*),'|',MAX(version+0),'|',SUM(IFNULL(checksum,0))) FROM \`$SRC_DB\`.flyway_schema_history WHERE success=1")
fb=$(q "SELECT CONCAT(COUNT(*),'|',MAX(version+0),'|',SUM(IFNULL(checksum,0))) FROM \`$DST_DB\`.flyway_schema_history WHERE success=1")
[ "$fa" = "$fb" ] || { echo "  LỆCH flyway: nguồn $fa, khôi phục $fb"; diff=$((diff+1)); }

size=$(du -h "$dump" | cut -f1)
echo
echo "Kết quả: $n bảng, $rows dòng; file $size; sao lưu $((t1-t0)) giây, khôi phục $((t2-t1)) giây; Flyway $fa (số bản|bản cao nhất|tổng checksum)."
if [ "$diff" -ne 0 ]; then echo "THẤT BẠI: $diff chỗ lệch."; exit 1; fi
echo "ĐẠT: bản khôi phục khớp nguồn. DB tạm: $DST_DB (xoá bằng tay khi xong)."
