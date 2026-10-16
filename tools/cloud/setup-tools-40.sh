#!/usr/bin/env bash
# Setup script cho môi trường cloud: cài sẵn 20 công cụ đồ hoạ / video / 3D / âm thanh ("Kỹ sư 4.0").
# Dán vào: menu môi trường cloud (thanh tiêu đề phiên) → Edit → Setup script.
#   bash /home/user/bosskin/tools/cloud/setup-tools-40.sh
# Chạy lại nhiều lần được (bỏ qua cái đã có). Cần mạng tới github.com và registry.npmjs.org (mức mạng Trusted trở lên).
# Mã tải về là mã ngoài: gói npm cài với --ignore-scripts (không chạy script cài đặt).
# Đặt SKIP_HEAVY=1 để bỏ các repo nặng (remotion, three.js, motion, FFmpeg — hơn 2,5 GB).
set -u
NPM_DIR=/root/tools4
SRC_DIR=/home/user
export GIT_LFS_SKIP_SMUDGE=1

# 1. Gói npm (bản đã build) → /root/tools4/node_modules
mkdir -p "$NPM_DIR" && cd "$NPM_DIR" || exit 0
[ -f package.json ] || npm init -y >/dev/null
npm install --ignore-scripts --no-audit --no-fund --no-progress \
  remotion @remotion/cli gsap animejs motion svgo satori three \
  @react-three/fiber @react-three/drei @react-three/rapier @react-three/postprocessing \
  howler mediabunny @rive-app/canvas @lottiefiles/dotlottie-web @motion-canvas/core @motion-canvas/2d \
  react react-dom || echo "npm install lỗi (tiếp tục)"

# 2. FFmpeg (bản chạy)
command -v ffmpeg >/dev/null || { apt-get update -qq && apt-get install -y -qq ffmpeg; } || echo "không cài được ffmpeg"

# 3. Mã nguồn 20 repo (nông, --depth 1) → /home/user/<chủ>/<repo>
REPOS="remotion-dev/skills motiondivision/ai-kit greensock/gsap-skills
svg/svgo vercel/satori
greensock/GSAP juliangarnier/anime rive-app/rive-wasm LottieFiles/dotlottie-web
motion-canvas/motion-canvas
pmndrs/react-three-fiber pmndrs/drei pmndrs/react-three-rapier pmndrs/react-postprocessing
goldfire/howler.js Vanilagy/mediabunny"
HEAVY="motiondivision/motion remotion-dev/remotion mrdoob/three.js FFmpeg/FFmpeg"
[ "${SKIP_HEAVY:-0}" = 1 ] || REPOS="$REPOS $HEAVY"
cd "$SRC_DIR" || exit 0
for r in $REPOS; do
  [ -d "$r/.git" ] && continue
  mkdir -p "$(dirname "$r")"
  git clone -q --depth 1 "https://github.com/$r" "$r" || echo "clone lỗi: $r"
done
echo "xong: npm ở $NPM_DIR, mã nguồn ở $SRC_DIR/<chủ>/<repo>"
