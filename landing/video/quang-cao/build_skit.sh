#!/usr/bin/env bash
# Dựng trọn một kịch bản: giọng → hình (Remotion) → ghép nhạc/giọng → ảnh bìa. Dùng: ./build_skit.sh <slug> [--no-voice]
# Cần: remotion (node_modules → /root/tools4/node_modules), ffmpeg, gTTS, numpy; trên cloud đặt SSL_CERT_FILE=/root/.ccr/ca-bundle.crt
set -e; cd "$(dirname "$0")"; slug="$1"
HS=${HEADLESS_SHELL:-$(ls -d /opt/pw-browsers/chromium_headless_shell-*/chrome-linux*/headless_shell | head -1)}
[ "$2" = "--no-voice" ] || python3 make_skit_voice.py "$slug"
node node_modules/.bin/remotion render src/index.ts Skit "out/skit-$slug.mp4" --props="{\"slug\":\"$slug\"}" --browser-executable="$HS"
python3 make_skit_audio.py "$slug"
ffmpeg -v error -y -ss 3.5 -i "out/final/skit-$slug.mp4" -frames:v 1 -q:v 3 "out/final/skit-$slug.jpg"
echo "xong: out/final/skit-$slug.mp4 (+ .jpg)"
