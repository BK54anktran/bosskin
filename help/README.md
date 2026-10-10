# Trang trợ giúp BossKin

Hướng dẫn sử dụng cho người dùng cuối (web desktop), chia theo vai trò, mỗi chức năng có các bước kèm ảnh chụp màn hình đánh dấu.
Là HTML tĩnh: đưa nguyên thư mục `help/` (trừ `src/`, `tools/`) lên host tĩnh bất kỳ (Netlify, S3 + CloudFront, `help.<tên-miền>`).

```
help/
  index.html, <trang>.html   ← kết quả dựng (commit cùng nguồn để host thẳng từ repo)
  img/<id>.webp              ← ảnh chụp đã đánh dấu (WebP, 1440×900 @1.5x)
  src/NN-<trang>.md          ← nội dung, sửa ở đây
  tools/                     ← dựng trang, seed dữ liệu mẫu, chụp ảnh
```

## Sửa nội dung

1. Sửa / thêm `help/src/NN-<trang>.md`. Phần đầu file:

   ```
   ---
   title: Tiêu đề trang
   group: Bắt đầu | Nhân viên | Quản lý | Nhân sự | Kế toán | Quản trị | Hỗ trợ
   who: Ai dùng
   summary: Một câu mô tả (hiện ở trang chủ và kết quả tìm kiếm)
   ---
   ```

   Số `NN` quyết định thứ tự; tên trang (`slug`) là phần sau, dùng để liên kết (`[xem](nghi-phep-ca-nhan.html#muc)`).
   Ảnh: `![Chú thích](img:<id>)`. Hộp lưu ý: `> **Lưu ý:** …` (hoặc `Mẹo:`, `Quan trọng:`).
2. `python3 help/tools/build_help.py` (cần `pip install markdown`) — sinh lại toàn bộ HTML + chỉ mục tìm kiếm.
3. Mở `help/index.html` kiểm tra.

Khi đổi giao diện / luồng của một màn, sửa trang trợ giúp tương ứng và chụp lại ảnh trong cùng commit.

## Chụp lại ảnh

Chỉ chạy trên **môi trường thử riêng** (DB riêng, ví dụ MySQL trong Docker) — các script tạo công ty mẫu và dữ liệu thật qua API.
Không chạy vào DB dev hay prod.

1. Dựng backend trên DB trống (bật `BOOTSTRAP_SYSADMIN_*`, `DOCUMENTS_STORAGE=local`) và bản web (`flutter build web`, phục vụ cổng 3000).
2. Dữ liệu mẫu — công ty hư cấu "Nội thất An Phát" (dùng chung với video giới thiệu):

   ```bash
   python3 landing/video/seed_demo.py http://localhost:8080 <email sysadmin> <mật khẩu sysadmin>
   python3 landing/video/prep_scenes.py            # nếu cần cảnh như video
   DEMO_API=http://localhost:8080 python3 help/tools/seed_help_extra.py
   ```

3. Chụp (Playwright + Chromium; OCR dự phòng cần `tesseract-ocr` + gói `vie`, `pytesseract`, `Pillow`):

   ```bash
   cd help/tools
   python3 capture.py all                 # hoặc tên chương: ca_nhan cham_cong luong …
   python3 montage.py /tmp/xem.png payroll-list payslip   # ghép ảnh để duyệt nhanh
   ```

   Biến môi trường: `HELP_WEB` (mặc định `http://localhost:3000`), `HELP_PW` (mật khẩu tài khoản mẫu), `HELP_IMG` (thư mục ảnh ra).
   Ảnh thô và bản dump semantics ở `tools/.raw/` (không commit). `explore.py <email> <route…>` in nhãn semantics của một màn để viết
   bước chụp mới.

Ảnh dùng giờ máy lúc chụp; dữ liệu mẫu tính theo "hôm nay" nên chụp lại sẽ ra ngày mới, nội dung giữ nguyên.
