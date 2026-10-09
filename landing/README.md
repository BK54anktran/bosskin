# Trang giới thiệu + video BossKin

Trang tĩnh (`index.html` + `assets/`), không cần build. Máy dev Windows: `dev\start.cmd landing` (hoặc `dev\start.cmd` chạy tất cả)
→ http://localhost:8099. Máy khác: `python3 -m http.server -d landing 8099`.

## Cấu hình trước khi đăng
Sửa khối `window.BOSSKIN` đầu `index.html`:

| Khoá | Ý nghĩa |
|---|---|
| `appUrl` | Link nút "Đăng nhập" tới app web (mặc định `/login`) |
| `contactEmail` | Email nhận yêu cầu dùng thử. Form mở ứng dụng email của khách với nội dung đã điền (trang không có backend) |
| `contactPhone` | Số điện thoại / Zalo hiện ở mục liên hệ (để trống thì ẩn) |

Số liệu trên trang lấy từ hệ thống thật: duyệt công 300 NV × 22 ngày đo được 47–50 giây (`docs/pilot-2026-10.md`),
8 báo cáo Excel, BHXH 8% / BHYT 1,5% / BHTN 1% + thuế TNCN luỹ tiến. Đổi tính năng thì sửa trang theo (quy tắc 2).

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
