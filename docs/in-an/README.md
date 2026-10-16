# Bộ tài liệu in đi sale

| File | Khổ | Dùng |
|---|---|---|
| `pdf/poster-a3.pdf` | A3 dọc (297 × 420 mm), 1 mặt | Treo / dựng tại văn phòng khách, sự kiện. Có QR đăng ký dùng thử + Zalo |
| `pdf/poster-bang-gia-a3.pdf` | A3 dọc, 1 mặt | Poster **bảng giá** (từ 5.000đ/NV/tháng, 3 gói theo chức năng) + dùng thử miễn phí 1 tháng + hỗ trợ cài đặt, xử lý sự cố 24/24. Giá gói 2, 3 ghi "báo giá theo quy mô" — có giá thì sửa HTML |
| `pdf/to-gioi-thieu-a4.pdf` | A4, **2 mặt** (in đảo mặt cạnh dài) | Tờ giới thiệu để lại cho khách: vấn đề, tính năng, hồ sơ nhân sự, cho ai, bắt đầu, hỏi đáp |
| `pdf/kich-ban-ban-hang.pdf` + `.docx` | A4, 4 trang | Kịch bản cho nhân viên kinh doanh: chuẩn bị, mở đầu, câu hỏi nhu cầu, demo trên Công ty test, xử lý từ chối, chốt, theo dõi + tin nhắn Zalo mẫu. **Sửa ở `kich-ban-ban-hang.md`** rồi chạy lại `build.py` |
| `pdf/phieu-dang-ky-a4.pdf` | A4, 1 mặt | Khách điền tay: doanh nghiệp, người liên hệ, nhu cầu, **mã công ty + đuôi email** để tạo tài khoản dùng thử |

Ảnh PNG từng trang (200 dpi) ở `anh/` — gửi Zalo / Facebook, hoặc kéo vào Canva: `poster-a3-1.png`, `to-gioi-thieu-a4-1.png` / `-2.png`,
`phieu-dang-ky-a4-1.png`, `kich-ban-ban-hang-1…4.png`.

## In
- Giấy gợi ý: poster couche 200–250 g (có thể cán mờ); tờ giới thiệu couche 150 g in 2 mặt; phiếu đăng ký giấy văn phòng 80 g.
- Nền màu chạy sát mép: dặn nhà in **in tràn lề** (hoặc chấp nhận viền trắng nhỏ khi in máy văn phòng).
- Chữ đã nhúng sẵn trong PDF (font Be Vietnam Pro, giấy phép OFL ở `fonts/OFL.txt`) — nhà in không cần cài font.
- Giá chỉ có ở `poster-bang-gia-a3` (khớp mục Bảng giá trên landing; thiết kế `docs/thiet-ke/bang-gia-landing.md`). Các tài liệu khác chưa có giá. Đổi giá → sửa cả poster, landing và tài liệu thiết kế.

## Sửa và xuất lại
Nội dung ở `poster-a3.html`, `to-gioi-thieu-a4.html`, `phieu-dang-ky-a4.html` (+ `common.css`), ảnh ở `img/`
(chép từ `landing/assets/`, QR tạo bằng thư viện `qrcode`: `qr-web` → https://bosskin.io.vn/#lien-he, `qr-zalo` → https://zalo.me/0865854002).
```
pip install playwright && python -m playwright install chromium
python docs/in-an/build.py      # → pdf/*.pdf, pdf/kich-ban-ban-hang.docx (cần pandoc + pip install markdown), preview/*.png
```
Đổi số điện thoại / website → sửa cả 3 file HTML + tạo lại QR, giữ khớp `landing/site-config.js`.
Đổi tính năng / ảnh màn hình chính → cập nhật cùng trang giới thiệu (quy tắc 2).
