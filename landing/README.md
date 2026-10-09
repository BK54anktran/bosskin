# Trang giới thiệu + video BossKin

Trang tĩnh (`index.html` + `assets/`), không cần build. Máy dev Windows: `dev\start.cmd landing` (hoặc `dev\start.cmd` chạy tất cả)
→ http://localhost:8099. Máy khác: `python3 -m http.server -d landing 8099`.

## Cấu hình trước khi đăng
Sửa khối `window.BOSSKIN` đầu `index.html`:

| Khoá | Ý nghĩa |
|---|---|
| `appUrl` | Link nút "Đăng nhập" tới app web. Để trống thì ẩn nút (khi app chưa lên mạng) |
| `apiUrl` | Backend BossKin nhận form dùng thử (vd `https://api.ten-mien.vn`, phải có trong `CORS_ALLOWED_ORIGINS`). Ưu tiên cao nhất |
| `supabaseUrl`, `supabaseKey` | Khi chưa có `apiUrl`: form ghi vào bảng `trial_requests` trên Supabase (khoá publishable, RLS chỉ cho THÊM). Không có cả hai → **Netlify Forms** |
| `contactEmail` | Email liên hệ hiện ở mục dùng thử (tuỳ chọn) |
| `contactPhone` | Số điện thoại / Zalo hiện ở mục liên hệ (để trống thì ẩn) |

Số liệu trên trang lấy từ hệ thống thật: duyệt công 300 NV × 22 ngày đo được 47–50 giây (`docs/pilot-2026-10.md`),
8 báo cáo Excel, BHXH 8% / BHYT 1,5% / BHTN 1% + thuế TNCN luỹ tiến. Đổi tính năng thì sửa trang theo (quy tắc 2).

## Yêu cầu dùng thử trên Supabase (đang dùng, 10/2026)
- Project Supabase `bosskin` (`apcppqwwnoyliwlhqtyx`), bảng `public.trial_requests` — cấu trúc ở `supabase/001_trial_requests.sql`.
- Trang chỉ được thêm dòng (RLS + quyền theo cột); trigger chuẩn hoá số điện thoại, bỏ qua trùng số trong 10 phút, tối đa 5 lượt/IP/giờ.
- Xem / xử lý: app BossKin `/admin` → tab **Yêu cầu dùng thử** (backend đọc Supabase khi `backend/.env` có `SUPABASE_URL` + `SUPABASE_SECRET_KEY`),
  hoặc Supabase Dashboard → **Table Editor → trial_requests**.
- `apiUrl` để trống: mọi nơi (kể cả `localhost:8099`) đều ghi vào Supabase — một nguồn duy nhất.

## Host trên Netlify
`netlify.toml` ở gốc repo đã cấu hình sẵn (thư mục `landing/`, không build, chỉ deploy khi `landing/` đổi, header bảo mật, cache ảnh/video).
1. app.netlify.com → **Add new site → Import an existing project → GitHub** → chọn repo `bosskin`, nhánh `main`. Để nguyên cấu hình (đọc từ `netlify.toml`) → **Deploy**.
2. **Site configuration → Forms → Enable form detection**, rồi **Deploys → Trigger deploy** một lần để Netlify nhận form `dung-thu`.
3. **Forms → dung-thu → Form notifications → Add notification → Email** để nhận email mỗi khi có yêu cầu (gói miễn phí 100 lượt/tháng).
4. (Tuỳ chọn) **Domain management** → gắn tên miền riêng; Netlify tự cấp HTTPS.

Khi backend lên mạng: đặt `apiUrl` (và `appUrl`) trong `index.html`, thêm tên miền trang vào `CORS_ALLOWED_ORIGINS` — form chuyển sang lưu vào BossKin.

## Video đầy đủ `assets/bosskin-gioi-thieu.mp4` (~90 giây, 1080p, giọng Hoài My, phụ đề in sẵn; trang dẫn link phụ)
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

## Video chính trên trang `assets/bosskin-reel.mp4` (~51 giây, 16:9, nền tối, nhạc + giọng nam Nam Minh; poster `reel-poster.jpg`)
Cùng bộ ảnh chụp ở trên. Lời đọc ở `video/script_reel.json`:
`python3 video/tts.py video/script_reel.json <thư mục giọng>` rồi
`python3 video/make_reel.py <thư mục ảnh> <thư mục giọng> landing/assets/bosskin-reel.mp4` (xem trước: thêm `--frames 5,20`).
Bản dọc 9:16 cho Reels / TikTok / Shorts (cùng giọng, nhạc, cảnh; không đưa lên trang): `python3 video/make_reel_vertical.py <thư mục ảnh> <thư mục giọng> <file .mp4>`
(chừa vùng an toàn trên ~220 px, dưới ~380 px cho chữ/nút của app). Bản đã dựng để đăng mạng xã hội lưu ngoài repo (`marketing/facebook/`).
Đổi lời / dựng lại thì tạo lại phụ đề `assets/bosskin-reel.vi.vtt` (thời điểm = đầu cảnh + 0,35 s, dài bằng file giọng — cùng cách tính độ dài cảnh trong `make_reel.py`).

## Màu chữ, khả năng tiếp cận, tốc độ
- Chữ nhấn dùng token `--accent` (sáng `#1d4ed8`, tối `#8ab4ff`), không dùng `--blue` cho chữ — `--blue` chỉ làm nền nút. Chữ phụ `--muted` đạt ≥ 4,5:1 trên cả `--bg` và `--bg-soft` ở hai chế độ màu.
- Nội dung chính nằm trong `<main>`; video có phụ đề `<track kind="captions">`.
- Ảnh chụp màn hình có bản nhỏ `*-w800.webp` / `*-w360.webp` (srcset), ảnh dưới màn hình đầu `loading="lazy"`, poster video dạng webp, font Google tải không chặn hiển thị. Thay ảnh thì tạo lại bản nhỏ cùng tên.


## Bài đăng hằng ngày (Facebook + TikTok qua Metricool)
- `video/make_post.py <spec.json> <thư mục ra>` → ảnh `.jpg` + video ngắn `.mp4` 9:16 (mô tả spec ở đầu file;
  ảnh giao diện lấy từ `video/shots/*.webp` — d_* màn hình máy tính, p_* điện thoại; lồng tiếng tuỳ chọn bằng edge-tts `vi-VN-NamMinhNeural`).
- Media đăng lên bucket công khai `social` của Supabase `bosskin` (upload bằng `SUPABASE_SECRET_KEY` trong `backend/.env`):
  `https://apcppqwwnoyliwlhqtyx.supabase.co/storage/v1/object/public/social/<ngày>/<file>`. Bản gốc giữ ở `marketing/social/<ngày>/` (không commit).
- Một scheduled task của Claude chạy mỗi sáng: chọn chủ đề (tính năng BossKin hoặc tin/quy định nhân sự – lương Việt Nam có nguồn),
  dựng bài, upload, rồi hẹn giờ đăng qua Metricool (brand BossKin: Trang Facebook + TikTok `bosskin_hrm`). Nhật ký chủ đề đã đăng:
  `marketing/social/log.md` để không lặp.
- Chạy hoàn toàn trên cloud: `video/tts_edge.py "<lời>" vo.mp3` lồng tiếng chỉ bằng thư viện chuẩn Python (không cần pip edge-tts).
  Bộ dựng đóng gói sẵn ở `https://bosskin.netlify.app/social/kit.tar.gz` (giải nén ra đúng cấu trúc repo). Sửa script/ảnh thì đóng gói lại:
  `tar czf landing/social/kit.tar.gz landing/video/{make_post.py,make_reel_vertical.py,make_reel.py,script_reel.json,tts_edge.py,shots} frontend/assets/images/bosskin_icons/round_512x512.png`
