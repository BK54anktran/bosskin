# Video quảng cáo BossKin (9:16, 25 giây)
Remotion (React) → `bosskin-quang-cao.mp4` (1080×1920, 30 fps, không có tiếng). Cảnh: mở đầu → chấm công → xếp ca → tổng quan → lương → giá từ 5.000đ/NV/tháng + dùng thử 1 tháng + hỗ trợ 24/24 + QR.
Nội dung giá khớp mục Bảng giá trên landing và poster (`docs/thiet-ke/bang-gia-landing.md`) — đổi giá thì sửa `src/Quangcao.tsx` (cảnh cuối) rồi dựng lại.

```
./prep.sh                      # chép ảnh / font / QR vào public/ (không commit)
# cần gói remotion (xem tools/cloud/setup-tools-40.sh, đặt node_modules → /root/tools4/node_modules)
npm run render                 # → out/bosskin-quang-cao.mp4  (dùng chromium headless-shell có sẵn)
npm run studio                 # xem / chỉnh trực tiếp
```
