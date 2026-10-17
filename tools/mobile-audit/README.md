# Kiểm tra giao diện điện thoại (390×844)

Quét tự động các màn Flutter web ở khung điện thoại, bấm qua tab / nút an toàn, bắt lỗi `RenderFlex overflowed`
kèm vị trí dòng code, và chụp ảnh từng bước. Dùng khi sửa giao diện (xem mục "Responsive điện thoại" trong CLAUDE.md).

## Cài một lần (máy cloud mới)
`bash tools/mobile-audit/setup.sh` — MySQL 8 (MariaDB không chạy được `V1__baseline.sql`), Flutter 3.47.6 ở `/opt/fl`,
venv Python cho seed. Chromium + Playwright đã có sẵn trên máy (`/opt/pw-browsers/chromium`, `npm root -g`/playwright).
Dán lệnh này vào **Setup script** của môi trường để lần sau không phải cài lại.

## Chạy
```
tools/mobile-audit/run.sh up       # MySQL + backend (:8080) + dữ liệu "Nội thất An Phát" + Flutter web (:3000)
TAG=lan1 tools/mobile-audit/run.sh crawl
tools/mobile-audit/run.sh reload   # sau khi sửa Dart
```
- Tài khoản mẫu: `admin@anphat.local` / `AnPhat2026demo`; nhân viên: `kd@anphat.local`.
  Đổi bằng `USER_EMAIL=… USER_PW=… ROUTES=/a,/b TAG=…` (xem `crawl.js`).
- Ảnh vào `$OUT` (mặc định `/tmp/mobile-audit/shots`, **không commit**); báo cáo `report-<TAG>.json`.
- `lib.js`: mở Chromium 390×844, chuyển đường dẫn tài nguyên `/v123/...` của Flutter debug về gốc, bật cây semantics để đọc nút / tab.
  Đăng nhập trong `crawl.js` bấm theo toạ độ ô email / mật khẩu của màn đăng nhập mobile — đổi bố cục màn đăng nhập thì chỉnh lại.
- Không bấm nút xoá / duyệt / khoá / đăng xuất… (regex `DANGER` trong `crawl.js`).
- Không quét được `/admin` (cần 2FA).

## Bẫy đã gặp
- Đừng bật `isMobile` của Playwright (lỗi "ViewInsets cannot be negative"): dùng viewport thường.
- Flutter chỉ in chi tiết lỗi tràn lần đầu; thêm dòng `forceReport` tạm vào `main.dart` để thấy mọi lần (xoá trước khi commit).
- Không dùng `pkill -f` / `pgrep -f` (khớp luôn lệnh của shell và giết nó).
- Ảnh mẫu trước / sau: `docs/thiet-ke/img/mobile-audit/`.
