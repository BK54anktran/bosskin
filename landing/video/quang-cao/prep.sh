#!/usr/bin/env bash
# Chép ảnh + font + QR từ landing/ và docs/in-an/ vào public/ (không commit) để Remotion dùng.
set -e
cd "$(dirname "$0")"; mkdir -p public
A=../../assets; I=../../../docs/in-an
cp $A/dt-cham-cong.webp $A/dt-phieu-luong.webp $A/man-xep-ca.webp $A/man-duyet-cong.webp $A/man-tong-quan.webp $A/man-bang-luong.webp $A/logo-192.png public/
cp $I/img/qr-web.svg public/
cp $I/fonts/be-vietnam-pro-{latin,latin-ext,vietnamese}-{600,800}-normal.woff2 public/
