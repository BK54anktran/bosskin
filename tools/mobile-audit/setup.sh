#!/usr/bin/env bash
# Dựng môi trường kiểm tra giao diện điện thoại trên máy cloud mới (chạy một lần; dán vào "Setup script" của môi trường để khỏi cài lại).
# Cần: MySQL 8 thật (MariaDB không chạy được V1 baseline), Flutter 3.47.6, Playwright + Chromium (đã có sẵn ở /opt/pw-browsers), Java 17 + Maven.
set -euo pipefail

# 1) MySQL 8 (apt) — datadir riêng, không dùng bản mặc định
if ! command -v mysqld >/dev/null; then
  apt-get update -qq && apt-get install -y -qq mysql-server-8.0
fi
mkdir -p /var/lib/mysql-files

# 2) Flutter 3.47.6 (ghim như CI) vào /opt/fl — chạy dưới root nên khi chạy flutter sẽ thấy cảnh báo "running as root", bỏ qua được
if [ ! -x /opt/fl/flutter/bin/flutter ]; then
  mkdir -p /opt/fl && cd /opt/fl
  curl -sS -o flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.6-stable.tar.xz
  tar xf flutter.tar.xz && rm flutter.tar.xz
  git config --global --add safe.directory /opt/fl/flutter
fi

# 3) Python cho script seed (landing/video/seed_demo.py)
python3 -m venv /tmp/ev 2>/dev/null || true
/tmp/ev/bin/pip install -q requests pillow || true

echo "Xong. Tiếp theo: tools/mobile-audit/run.sh"
