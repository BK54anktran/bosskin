# Trang giới thiệu + video BossKin

Trang tĩnh (`index.html` + `assets/`), không cần build. Máy dev Windows: `dev\start.cmd landing` (hoặc `dev\start.cmd` chạy tất cả)
→ http://localhost:8099. Máy khác: `python3 -m http.server -d landing 8099`.

## Cấu hình trước khi đăng
Sửa khối `window.BOSSKIN` đầu `index.html`:

| Khoá | Ý nghĩa |
|---|---|
| `appUrl` | Link nút "Đăng nhập" tới app web. Để trống thì ẩn nút (khi app chưa lên mạng) |
| `apiUrl` | Backend BossKin nhận form dùng thử (vd `https://api.ten-mien.vn`, phải có trong `CORS_ALLOWED_ORIGINS`). Để trống thì form gửi vào **Netlify Forms** |
| `contactEmail` | Email liên hệ hiện ở mục dùng thử (tuỳ chọn) |
| `contactPhone` | Số điện thoại / Zalo hiện ở mục liên hệ (để trống thì ẩn) |

Số liệu trên trang lấy từ hệ thống thật: duyệt công 300 NV × 22 ngày đo được 47–50 giây (`docs/pilot-2026-10.md`),
8 báo cáo Excel, BHXH 8% / BHYT 1,5% / BHTN 1% + thuế TNCN luỹ tiến. Đổi tính năng thì sửa trang theo (quy tắc 2).

## Host trên Netlify
`netlify.toml` ở gốc repo đã cấu hình sẵn (thư mục `landing/`, không build, chỉ deploy khi `landing/` đổi, header bảo mật, cache ảnh/video).
1. app.netlify.com → **Add new site → Import an existing project → GitHub** → chọn repo `bosskin`, nhánh `main`. Để nguyên cấu hình (đọc từ `netlify.toml`) → **Deploy**.
2. **Site configuration → Forms → Enable form detection**, rồi **Deploys → Trigger deploy** một lần để Netlify nhận form `dung-thu`.
3. **Forms → dung-thu → Form notifications → Add notification → Email** để nhận email mỗi khi có yêu cầu (gói miễn phí 100 lượt/tháng).
4. (Tuỳ chọn) **Domain management** → gắn tên miền riêng; Netlify tự cấp HTTPS.

Khi backend lên mạng: đặt `apiUrl` (và `appUrl`) trong `index.html`, thêm tên miền trang vào `CORS_ALLOWED_ORIGINS` — form chuyển sang lưu vào BossKin.

## Video `assets/bosskin-gioi-thieu.mp4` (~90 giây, 1080p, giọng Hoài My, phụ đề in sẵn)
Dựng lại toàn bộ bằng các script trong `video/` (chạy trên môi trường thử riêng, **không** chạy vào DB dev/prod):

1. Backend + bản web (`flutter build web`, phục vụ ở `localhost:3000`) trên DB thử trống hoặc DB thử riêng.
2. `python3 video/seed_demo.py http://localhost:8080 <email system admin> <mật khẩu>` — tạo công ty hư cấu
   "Nội thất An Phát" (24 NV, ca, phép, công tháng trước đã chốt, lương đã trả). Khoá 2FA system admin lưu ở `video/.demo-totp` (không commit).
3. `python3 video/prep_scenes.py` — mẫu xoay ca, đơn đổi ca, ca hôm nay cho cảnh chấm công điện thoại (chạy ngay trước bước 4).
4. Chụp màn hình: `capture_phone.py <thư mục ảnh>`, rồi `capture_desktop.py <thư mục ảnh> views|leave|payroll|profile`,
   cuối cùng `capture_desktop.py <thư mục ảnh> approve` (bước này duyệt công thật trên DB thử).
5. Lồng tiếng: sửa lời ở `video/script.json`, chạy `python3 video/tts.py video/script.json <thư mục giọng>` (cần `pip install edge-tts`).
6. `python3 video/make_video.py <thư mục ảnh> <thư mục giọng> landing/assets/bosskin-gioi-thieu.mp4` — dựng chuyển động,
   con trỏ, phụ đề, nhạc nền tổng hợp (không bản quyền). Xem trước vài khung: thêm `--frames 5,20,40`.

Đổi giao diện app thì chụp lại (bước 4) — toạ độ bấm trong `capture_*.py` và `make_video.py` là toạ độ CSS của bản web hiện tại.
Poster video: `ffmpeg -ss 9.6 -i assets/bosskin-gioi-thieu.mp4 -frames:v 1 assets/video-poster.jpg`.
