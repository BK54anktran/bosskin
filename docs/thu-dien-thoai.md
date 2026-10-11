# Thử BossKin trên điện thoại thật (bước D)

Mục tiêu: đi hết checklist trên **ít nhất 1 máy Android** mà không gặp lỗi chặn. Ghi kết quả vào cột cuối
(✔ / ✘ + mô tả ngắn, ảnh chụp màn hình nếu lỗi) rồi gửi lại để sửa.

## Chuẩn bị

| Việc | Ghi chú |
|---|---|
| APK | Tải từ GitHub Actions → **Frontend build** → artifact `bosskin-apk` (cần đủ 4 secrets khoá ký, runbook mục 10; thiếu thì APK ký debug vẫn cài được để thử) |
| Máy chủ | Backend chạy được từ điện thoại (bản AWS, hoặc máy dev cùng mạng Wi-Fi: build APK với `API_HOST=http://<IP máy dev>:8080`) |
| Firebase | Khoá service account mới đặt vào `FIREBASE_SERVICE_ACCOUNT_JSON` (khoá cũ đã lộ, phải thay) và `google-services.json` khớp project |
| Tài khoản | 1 admin công ty, 2 nhân viên (A, B) cùng phòng ban có toạ độ + bán kính chấm công; A có ca hôm nay. Tài khoản tạo mới (mật khẩu tạm) |
| Máy | Android 10 trở lên, bật định vị. Nên có thêm 1 máy Android thứ hai để thử đổi máy |

## Checklist

| # | Kịch bản | Cách làm | Kết quả đúng | Kết quả |
|---|---|---|---|---|
| 1 | Cài đặt | Cài APK, mở app | Màn đăng nhập, chữ tiếng Việt đủ dấu, không lỗi font | |
| 2 | Bắt đổi mật khẩu | Đăng nhập NV A bằng mật khẩu tạm | Chuyển ngay sang màn đổi mật khẩu; mật khẩu yếu (< 8 ký tự hoặc thiếu số) bị chặn; đổi xong vào được app | |
| 3 | Quyền vị trí | Bấm Chấm công lần đầu | Hỏi quyền vị trí; từ chối thì báo cần quyền, không treo | |
| 4 | Chấm vào trong vùng | Đứng trong bán kính phòng ban, bấm Chấm vào | Thành công, giờ vào hiện đúng; máy được gắn với tài khoản | |
| 5 | Chấm ngoài vùng | Đi ra ngoài bán kính (hoặc chỉnh toạ độ phòng ban cách xa), chấm ra | Báo "ngoài phạm vi", không ghi công | |
| 6 | GPS kém / giả lập vị trí | Bật app giả vị trí (Developer options → Mock location) rồi chấm | Báo vị trí giả, không ghi công | |
| 7 | Chấm ra | Trong vùng, sau giờ ra ca | Thành công; bảng công của A ở web hiện đủ vào/ra | |
| 8 | Gắn thiết bị | Đăng nhập A trên máy thứ hai, chấm công | Báo tài khoản đã gắn máy khác, không ghi công | |
| 9 | Đổi máy | Admin: Nhân viên → A → Gỡ thiết bị; A chấm lại trên máy thứ hai | Chấm được; nhật ký có dòng gỡ thiết bị | |
| 10 | Thông báo đẩy | Cho phép thông báo; B gửi đơn nghỉ, admin duyệt trên web | A/B nhận thông báo cả khi app chạy nền và khi đã đóng app; bấm vào mở đúng màn | |
| 11 | Nhắc chấm công | Để A có ca, không chấm vào | Nhận thông báo nhắc trước / sau giờ vào ca theo cài đặt công ty | |
| 12 | Mất mạng giữa chừng | Bật chế độ máy bay, bấm Chấm vào | Báo lỗi mạng rõ ràng, không báo thành công giả; bật mạng lại chấm được, không tạo 2 dòng | |
| 13 | Mạng chập chờn khi gửi đơn | Gửi đơn nghỉ, tắt mạng ngay khi bấm Gửi | Báo lỗi hoặc thành công đúng một lần; mở lại danh sách không có đơn trùng | |
| 14 | Hết phiên | Để app nền > 30 phút rồi mở lại, thao tác | Tự làm mới phiên (không bị văng); sau 7 ngày không dùng thì về màn đăng nhập | |
| 15 | Đơn từ | A gửi đơn nghỉ phép, đơn sửa giờ, đơn đổi ca với B | Gửi được, trạng thái cập nhật sau khi duyệt; số phép còn lại trừ đúng | |
| 16 | Phiếu lương | Admin tạo + duyệt bảng lương kỳ có công của A; A mở Lương của tôi | Thấy phiếu, số khớp web; không thấy phiếu của người khác | |
| 17 | Tài liệu | A vào Hồ sơ → Tài liệu của tôi, gửi ảnh CCCD chụp từ camera | Gửi được (chờ duyệt); admin duyệt trên web; A mở xem / tải được | |
| 18 | Ảnh đại diện | Đổi ảnh đại diện từ thư viện ảnh | Ảnh hiện ở Hồ sơ và danh sách NV | |
| 19 | 2FA (admin) | Admin đăng nhập trên điện thoại, Hồ sơ → bật 2FA bằng Google Authenticator | Quét QR được; đăng xuất / đăng nhập lại phải nhập mã | |
| 20 | Giao diện tối | Hồ sơ → Giao diện → Tối; đổi về Theo máy rồi bật chế độ tối của Android | Các màn đọc rõ, đổi ngay không cần mở lại app | |
| 21 | Ngôn ngữ | Đổi sang English | Toàn bộ chữ đổi sang tiếng Anh, thông báo lỗi cũng tiếng Anh | |
| 22 | Xoay màn hình / màn nhỏ | Xoay ngang; thử trên máy màn 5–6 inch | Không tràn chữ, không nút bị che | |
| 23 | Pin / chạy nền | Để app nền 1 ngày | Không hao pin bất thường (Cài đặt → Pin) | |
| 24 | Gửi thông báo thử | Hồ sơ → Cài đặt thông báo → bật một loại → **Gửi thông báo thử** | Vài giây sau nhận thông báo "BossKin — thông báo thử" (cả khi app đang mở và khi đã về màn hình chính); tắt hết các loại thì app nhắc bật trước | |

## Lỗi chặn là gì

Không chấm công được khi đúng điều kiện, chấm công được khi sai điều kiện (ngoài vùng, giả vị trí, máy khác),
ghi trùng / mất công, không đăng nhập được, văng app, số lương / phép sai. Các lỗi giao diện nhỏ ghi lại nhưng không chặn.
