# Trang giới thiệu + video BossKin

Trang tĩnh (`index.html` + `assets/`), không cần build. Máy dev Windows: `dev\start.cmd landing` (hoặc `dev\start.cmd` chạy tất cả)
→ http://localhost:8099. Máy khác: `python3 -m http.server -d landing 8099`.

## Cấu hình trước khi đăng
Sửa `window.BOSSKIN` trong `site-config.js` (dùng chung cho trang giới thiệu và trang trợ giúp `/help/`):

| Khoá | Ý nghĩa |
|---|---|
| `appUrl` | Link nút "Đăng nhập" tới app web. Để trống thì ẩn nút (khi app chưa lên mạng) |
| `apiUrl` | Backend BossKin nhận form dùng thử (vd `https://api.ten-mien.vn`, phải có trong `CORS_ALLOWED_ORIGINS`). Ưu tiên cao nhất |
| `supabaseUrl`, `supabaseKey` | Khi chưa có `apiUrl`: form ghi vào bảng `trial_requests` trên Supabase (khoá publishable, RLS chỉ cho THÊM). Phải có `apiUrl` hoặc Supabase, không thì form báo lỗi |
| `contactEmail` | Email liên hệ hiện ở mục dùng thử (tuỳ chọn) |
| `contactPhone` | Số điện thoại / Zalo hiện ở mục dùng thử và chân trang (để trống thì ẩn) |
| `facebookUrl`, `tiktokUrl`, `youtubeUrl` | Link trang mạng xã hội, hiện thành biểu tượng ở chân trang (để trống thì ẩn) |

Số liệu trên trang lấy từ hệ thống thật: duyệt công 300 NV × 22 ngày đo được 47–50 giây (`docs/pilot-2026-10.md`),
8 báo cáo Excel, BHXH 8% / BHYT 1,5% / BHTN 1% + thuế TNCN luỹ tiến. Đổi tính năng thì sửa trang theo (quy tắc 2).

## Yêu cầu dùng thử trên Supabase (đang dùng, 10/2026)
- Project Supabase `bosskin` (`apcppqwwnoyliwlhqtyx`), bảng `public.trial_requests` — cấu trúc ở `supabase/001_trial_requests.sql`.
- Trang chỉ được thêm dòng (RLS + quyền theo cột); trigger chuẩn hoá số điện thoại, bỏ qua trùng số trong 10 phút, tối đa 5 lượt/IP/giờ.
- Xem / xử lý: app BossKin `/admin` → tab **Yêu cầu dùng thử** (backend đọc Supabase khi `backend/.env` có `SUPABASE_URL` + `SUPABASE_SECRET_KEY`),
  hoặc Supabase Dashboard → **Table Editor → trial_requests**.
- `apiUrl` để trống: mọi nơi (kể cả `localhost:8099`) đều ghi vào Supabase — một nguồn duy nhất.

Khi backend lên mạng: đặt `apiUrl` (và `appUrl`) trong `site-config.js`, thêm tên miền trang vào `CORS_ALLOWED_ORIGINS` — form chuyển sang lưu vào BossKin.

## File cài Android trên trang (nút "Tải cho Android", 11/10/2026)

- Nút ở mục **Cài đặt** tải `apkUrl` trong `site-config.js` = file `bosskin.apk` của release GitHub **`app-latest`**. `apkUrl` trống → nút
  chuyển sang hướng dẫn thêm lối tắt trình duyệt. iPhone luôn là hướng dẫn "Thêm vào MH chính" (Apple không cho trang web tự cài).
- **Khoá ký phát hành** nằm trên máy dev, KHÔNG có trong repo: `frontend/android/app/release.jks` + `frontend/android/key.properties`
  (mật khẩu). Mất hai file này thì mọi người dùng phải gỡ app cài lại mới cập nhật được → sao lưu ra nơi an toàn.
  Bản sao của khoá nằm ở GitHub Secrets `ANDROID_KEYSTORE_BASE64` / `_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` (đưa lên bằng API, 11/10/2026).
- Ra bản mới: tăng `version` trong `frontend/pubspec.yaml` rồi push `main` — workflow **Frontend build** build, ký và thay `bosskin.apk` ở release `app-latest`
  (số build = số lần chạy workflow nên Android luôn coi là bản mới hơn). Build tay trên máy dev vẫn được: `flutter build apk --release --dart-define=API_HOST=https://api.bosskin.io.vn`.

## Đa ngôn ngữ vi / en (17/10/2026)
- `landing/index.html` là bản tiếng Việt (nguồn). Bản tiếng Anh `landing/en/index.html` (https://bosskin.io.vn/en/) **sinh tự động**, không sửa tay:
  `python3 tools/landing/build_i18n.py` (từ `index.html` + bảng `landing/i18n/en.json`: câu tiếng Việt → câu tiếng Anh, khoá gộp khoảng trắng).
  Sửa chữ trong `index.html` → thêm / sửa dòng cùng khoá trong `en.json` rồi chạy lại; chữ Việt chưa có bản dịch thì script báo lỗi. CI `site-check.yml` chạy `--check`.
- Menu đầu trang (Cài đặt, Video, … Trợ giúp) khai báo **một chỗ** ở `tools/landing/chrome.py` (`NAV`), dùng cho cả trang giới thiệu (`build_i18n.py` ghi lại `<nav class="links">` trong `index.html`)
  và trang trợ giúp (`build_help.py`): thêm / đổi mục menu ở đó rồi chạy cả hai script. CSS đầu trang vẫn là hai bản (`index.html`, `help/tools/help.css`) — đổi kiểu thì sửa cả hai.
- Chuỗi trong JS (lỗi form, "Đang gửi…", dòng liên hệ) nằm trong `TXT` / `ERR` của `index.html`, chọn theo `<html lang>`; form gửi `Accept-Language` theo trang.
- Chọn ngôn ngữ bằng danh sách thả xuống (`<details class="lang-dd">`, không cần JS) ở thanh trên cả trang giới thiệu và trợ giúp; danh sách ngôn ngữ nằm ở `LANGS` trong `tools/landing/chrome.py`.
  **Thêm ngôn ngữ mới** (vd. `ja`): thêm `('ja', '日本語')` vào `LANGS`, tạo `landing/i18n/ja.json` (khoá tiếng Việt → câu mới, copy từ `en.json`) và `help/src-ja/`, rồi mở rộng `build_i18n.py` / `build_help.py` (hiện đang cố định `en`: tham số hoá theo `LANGS`), `check_sitemap.py`, Dockerfile (`help/ja`).
- Lựa chọn ngôn ngữ; nhớ trong `localStorage` (`bk_lang`), trang tiếng Việt chỉ tự chuyển sang `/<mã>/` khi người dùng đã chọn English (không dò ngôn ngữ trình duyệt để khỏi ảnh hưởng SEO).
  Cả hai trang có canonical riêng + `hreflang` vi / en / x-default; `/en/` có trong sitemap.
- Trang trợ giúp `/help/`, ảnh chụp màn hình và video vẫn tiếng Việt (chưa có bản Anh).

## SEO: sitemap.xml, robots.txt, Google Search Console (12/10/2026)

- `sitemap.xml` **sinh tự động** bởi `python3 help/tools/build_help.py` (trang chủ + `/help/` + 22 trang trợ giúp, URL đúng bằng canonical
  của từng trang) — không sửa tay. `robots.txt` viết tay: cho phép toàn trang + dòng `Sitemap:`. `404.html` có `noindex`.
  Ứng dụng (`app.`) và API (`api.`) là tên miền riêng, không nằm trong sitemap này. Kiểm: `python3 tools/ci/check_sitemap.py` (CI `site-check.yml`).
- Nginx trả `sitemap.xml` kiểu `application/xml`.
- Sau khi deploy: `curl -sI https://bosskin.io.vn/sitemap.xml` (200, `application/xml`), `curl -s https://bosskin.io.vn/robots.txt`.
  Search Console (thuộc tính `bosskin.io.vn`) → Lập chỉ mục → Sơ đồ trang web → gửi `https://bosskin.io.vn/sitemap.xml`;
  Kiểm tra URL → Yêu cầu lập chỉ mục cho `/` và `/help/`. Google tự quyết định có lập chỉ mục và khi nào; xem báo cáo Trang để biết lý do bị loại.

## Host trên Vibe Host (host duy nhất từ 12/10/2026, đã gỡ Netlify)

Website Docker từ thư mục `landing/` (`landing/Dockerfile` + `nginx.conf`): Nginx phục vụ trang giới thiệu, trang trợ giúp được lấy từ
`help/` trên nhánh `main` của GitHub lúc build và đặt ở `/help/`. Không chép `video/`, `supabase/`, `social/`, `README.md` (`.dockerignore`).
Sửa `help/` → triển khai lại website này để cập nhật. Form dùng thử ghi Supabase.

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
- Media đăng lên bucket công khai `social` của Supabase `bosskin` (`supabase/003_social.sql`): task trên cloud tải lên bằng khoá publishable vào
  thư mục bí mật `auto-…/<ngày>/` (chỉ thêm mới, jpg/mp4). Nhật ký bài: bảng `public.social_posts`.
- Một scheduled task của Claude chạy mỗi sáng: chọn chủ đề (tính năng BossKin hoặc tin/quy định nhân sự – lương Việt Nam có nguồn),
  dựng bài, upload, rồi hẹn giờ đăng qua Metricool (brand BossKin: Trang Facebook + TikTok `bosskin_hrm`). Không cần bật máy tính.
- Chạy hoàn toàn trên cloud: `video/tts_edge.py "<lời>" vo.mp3` lồng tiếng chỉ bằng thư viện chuẩn Python (không cần pip edge-tts).
  Bộ dựng đóng gói sẵn ở `https://bosskin.io.vn/social/kit.tar.gz` (giải nén ra đúng cấu trúc repo). Sửa script/ảnh thì đóng gói lại:
  `tar czf landing/social/kit.tar.gz landing/video/{make_post.py,make_reel_vertical.py,make_reel.py,script_reel.json,tts_edge.py,shots} frontend/assets/images/bosskin_icons/round_512x512.png`
