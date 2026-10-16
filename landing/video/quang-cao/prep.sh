#!/usr/bin/env bash
# Chép ảnh + font + QR từ landing/ và docs/in-an/ vào public/ (không commit) để Remotion dùng.
set -e
cd "$(dirname "$0")"; mkdir -p public
A=../../assets; I=../../../docs/in-an
cp $A/dt-cham-cong.webp $A/dt-phieu-luong.webp $A/man-xep-ca.webp $A/man-duyet-cong.webp $A/man-tong-quan.webp $A/man-nghi-phep.webp $A/man-nhat-ky.webp $A/man-bang-luong.webp $A/logo-192.png public/
cp $I/img/qr-web.svg public/
cp $I/fonts/be-vietnam-pro-{latin,latin-ext,vietnamese}-{600,800}-normal.woff2 public/
# Ảnh màn hình máy tính cắt vùng chính từ landing/video/shots (3200x1800) → public/shot-*.webp
python3 - <<'PY'
from PIL import Image
crops = {'d_swaps': (0, 0, 2000, 1125), 'd_shift_rotation': (0, 0, 2200, 1238), 'd_roles': (0, 0, 2400, 1350), 'd_profile_2fa': (900, 150, 3200, 1444)}
for n, c in crops.items():
    im = Image.open(f'../shots/{n}.webp').convert('RGB').crop(c)
    im.resize((1400, round(1400 * im.height / im.width))).save(f'public/shot-{n}.webp', quality=88)
PY
