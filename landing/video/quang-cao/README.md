# Video quảng cáo BossKin (9:16, 25 giây)
Remotion (React) → `bosskin-quang-cao.mp4` (1080×1920, 30 fps, không có tiếng). Cảnh: mở đầu → chấm công → xếp ca → tổng quan → lương → giá từ 5.000đ/NV/tháng + dùng thử 1 tháng + hỗ trợ 24/24 + QR.
Âm thanh: `python3 make_audio.py` (nhạc nền tự tạo; giọng đọc tuỳ chọn — xem `vo/loi-doc.txt`).
Nội dung giá khớp mục Bảng giá trên landing và poster (`docs/thiet-ke/bang-gia-landing.md`) — đổi giá thì sửa `src/Quangcao.tsx` (cảnh cuối) rồi dựng lại.

```
./prep.sh                      # chép ảnh / font / QR vào public/ (không commit)
# cần gói remotion (xem tools/cloud/setup-tools-40.sh, đặt node_modules → /root/tools4/node_modules)
npm run render                 # → out/bosskin-quang-cao.mp4  (dùng chromium headless-shell có sẵn)
npm run studio                 # xem / chỉnh trực tiếp
```

## Bộ video "cãi vã → BossKin", mỗi module một video (~30 giây, 9:16)
Hoạt hình tự vẽ (không dùng clip có bản quyền): nhân viên và sếp cãi nhau vì một vấn đề của module → BossKin giải quyết → giá từ 5.000đ/NV/tháng, dùng thử miễn phí 1 tháng, hỗ trợ 24/24, hotline.
Kịch bản `skits/<slug>.json` (7 module: cham-cong, xep-ca, nghi-phep, duyet-cong, tinh-luong, nhat-ky, bao-cao); thêm module mới → thêm file JSON + dòng trong `src/skits.ts` + ảnh vào `prep.sh`.
```
./build_skit.sh <slug>    # giọng (gTTS) → hình (Remotion, composition "Skit") → ghép giọng + nhạc → out/final/skit-<slug>.mp4 + .jpg
```
Giọng gTTS: nhân viên cao, sếp trầm, người dẫn giữ nguyên; độ dài từng cảnh tự co giãn theo giọng. Trên cloud đặt `SSL_CERT_FILE=/root/.ccr/ca-bundle.crt REQUESTS_CA_BUNDLE=/root/.ccr/ca-bundle.crt`.
Quy tắc nội dung (chủ dự án): chữ trên video chỉ ghi website + "Hotline: 0865 854 002", không nhắc tên nền tảng khác.
Video thành phẩm đăng tự động hằng ngày qua tác vụ đăng bài (mỗi ngày một module, xoay vòng); file mp4 nằm ở kho media Supabase, không commit.
