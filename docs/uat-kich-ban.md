# Kịch bản nghiệm thu (UAT) BossKin — trước go-live

Mục tiêu: đại diện từng vai trò của công ty pilot tự bấm qua các nghiệp vụ hằng tháng trên **bản chạy thật**
(staging hoặc prod trước khi mở cho toàn công ty) và xác nhận kết quả đúng với cách làm hiện tại.
Kịch bản trên điện thoại (GPS, gắn máy, thông báo đẩy) nằm riêng ở `docs/thu-dien-thoai.md` — UAT không lặp lại.

Ghi kết quả vào cột cuối: ✔ / ✘ + mô tả ngắn, ảnh chụp màn hình nếu sai. Mục ✘ mức **Chặn** phải sửa và thử lại
trước go-live; mức **Thường** được go-live nếu có cách làm tạm và hẹn ngày sửa.

## Chuẩn bị

| Việc | Ghi chú |
|---|---|
| Môi trường | Bản build mới nhất từ `main`, DB riêng (không dùng DB dev). Đã chạy diễn tập sao lưu / khôi phục (`tools/ops/backup_restore_drill.sh`, runbook mục 5) |
| Dữ liệu | Nhập dữ liệu thật theo `docs/chuyen-du-lieu.md` (phòng ban, chức vụ, bậc lương, ca, NV, số dư phép, hợp đồng). Đối chiếu số NV / phòng ban với danh sách HR đang giữ |
| Tài khoản | Xuất mật khẩu tạm (Phân quyền → Người dùng → **Xuất mật khẩu tạm**) và phát cho người tham gia; mỗi người tự đổi mật khẩu ở lần đăng nhập đầu |
| Vai trò | **HR** (quản lý nhân sự, toàn công ty) · **QL** (quản lý chấm công một phòng, có phạm vi) · **KT** (kế toán lương) · **NV** (2 nhân viên A, B cùng phòng của QL) · **GĐ** (Tổng quan, báo cáo) |
| Kỳ thử | Chọn 1 kỳ lương đã kết thúc ở cách làm cũ để so số (công, phép, lương) |

## Kịch bản

### 1. Tài khoản & phân quyền

| # | Vai trò | Kịch bản | Kết quả đúng | Mức | Kết quả |
|---|---|---|---|---|---|
| 1.1 | Mọi người | Đăng nhập bằng mật khẩu tạm | Bắt đổi mật khẩu (≥ 8 ký tự, có chữ và số), đổi xong vào đúng màn chính | Chặn | |
| 1.2 | HR | Đặt lại mật khẩu cho NV A (biểu tượng chìa khoá ở tab Người dùng) | Hiện mật khẩu tạm một lần; A đăng nhập bằng mật khẩu cũ bị từ chối, bằng mật khẩu tạm thì phải đổi | Chặn | |
| 1.3 | QL | Mở Nhân viên, Chấm công, Ca làm | Chỉ thấy NV trong phòng mình (và phòng con nếu phạm vi cho phép) | Chặn | |
| 1.4 | NV | Mở menu trái | Chỉ có nhóm Của tôi, Đơn từ & phê duyệt; gõ thẳng đường dẫn `/payroll` bị chặn | Chặn | |
| 1.5 | HR | Phân quyền → tạo vai trò "Trưởng ca", chọn quyền + phạm vi phòng ban, gán cho 1 người | Người đó thấy đúng màn và đúng phạm vi sau khi đăng nhập lại | Thường | |
| 1.6 | GĐ | Bật 2FA ở Hồ sơ | Lần đăng nhập sau phải nhập mã; 8 mã dự phòng dùng được một lần | Thường | |

### 2. Hồ sơ nhân sự

| # | Vai trò | Kịch bản | Kết quả đúng | Mức | Kết quả |
|---|---|---|---|---|---|
| 2.1 | HR | Thêm NV mới qua form | Mã NV tự cấp nối tiếp, không trùng (kể cả sau khi đã xoá NV khác) | Chặn | |
| 2.2 | HR | Xuất Excel NV → sửa SĐT, CCCD (gõ số bắt đầu bằng 0) → nhập lại qua xem trước | Xem trước đúng thay đổi; sau khi nhập SĐT / CCCD còn số 0 đầu | Chặn | |
| 2.3 | HR | Đổi phòng ban cha trong Phòng ban; thử chọn phòng con làm cha | Đổi được; chọn phòng con báo lỗi vòng lặp; sơ đồ tổ chức đúng cấp | Thường | |
| 2.4 | HR | Chuyển phòng NV có hiệu lực tháng sau (Quá trình công tác) | Hôm nay NV vẫn ở phòng cũ; đúng ngày tự chuyển | Thường | |
| 2.5 | NV A | Hồ sơ → gửi yêu cầu sửa SĐT | HR thấy yêu cầu; QL không có quyền sửa hồ sơ thì không thấy; HR duyệt xong, đơn hiện giá trị trước → sau | Thường | |
| 2.6 | HR | Hợp đồng: tạo HĐ xác định thời hạn, phụ lục tăng lương giữa kỳ, xem "Cần gia hạn" | Thời hạn kiểm đúng loại HĐ; HĐ sắp hết hạn có trong danh sách và ô Tổng quan | Chặn | |
| 2.7 | HR | Tài liệu: duyệt CCCD NV A gửi; xem "Thiếu bắt buộc" | Link xem chỉ mở được vài phút; nhật ký ghi lần xem | Thường | |
| 2.8 | HR | Người phụ thuộc của NV, MST, sổ BHXH | Người không có quyền dữ liệu nhạy cảm chỉ thấy `****1234` | Chặn | |

### 3. Ca làm & chấm công

| # | Vai trò | Kịch bản | Kết quả đúng | Mức | Kết quả |
|---|---|---|---|---|---|
| 3.1 | QL | Phân ca tuần tới cho phòng (lưới phân ca), thử 2 ca chồng giờ | Lưu được; ca chồng giờ bị chặn; ngày lễ tô màu | Chặn | |
| 3.2 | QL | Tạo mẫu xoay ca, sinh phân ca tháng sau, bỏ qua ngày lễ | Ngày đã có công giữ nguyên; ngày lễ không xếp ca | Thường | |
| 3.3 | NV A, B | Đổi ca với nhau; QL duyệt | Phân ca hai người đổi đúng sau khi duyệt | Thường | |
| 3.4 | QL | Bảng công kỳ thử: so từng NV với bảng chấm cũ (`tools/onboarding/doi_chieu.py`) | Chênh lệch có giải thích được (đi muộn theo dung sai, làm tròn, OT) | Chặn | |
| 3.5 | NV A | Gửi đơn sửa giờ vào (quên chấm) | QL duyệt → giờ trong bảng công đổi theo đơn; NV không tự duyệt được | Chặn | |
| 3.6 | QL | "Duyệt cả kỳ" cho phòng | Chỉ duyệt ngày đã qua; dòng thiếu giờ vào / ra để lại duyệt từng dòng | Chặn | |
| 3.7 | HR | Khoá kỳ công; thử sửa công ngày trong kỳ đã khoá | Bị chặn; mở khoá thì sửa được; nhật ký ghi khoá / mở | Chặn | |

### 4. Nghỉ phép

| # | Vai trò | Kịch bản | Kết quả đúng | Mức | Kết quả |
|---|---|---|---|---|---|
| 4.1 | HR | Kiểm số dư phép đầu kỳ của 5 NV so với sổ phép cũ | Khớp | Chặn | |
| 4.2 | NV A | Xin nghỉ phép năm 3 ngày qua cuối tuần | Chỉ trừ ngày có ca, bỏ ngày lễ; số dư giảm đúng | Chặn | |
| 4.3 | NV B | Xin nghỉ theo giờ trùng giờ nghỉ trưa | Không trừ phần giờ nghỉ trưa | Thường | |
| 4.4 | QL / HR | Duyệt rồi huỷ một đơn | Phép hoàn đúng quỹ đã trừ (Lịch sử phép → Sổ trừ/hoàn) | Chặn | |
| 4.5 | HR | Bật "quản lý trực tiếp duyệt trước" (Cài đặt công ty) | Đơn của A tới QL trước ("Duyệt cho nhóm"), HR duyệt cuối; QL từ chối thì hoàn phép | Thường | |

### 5. Lương

| # | Vai trò | Kịch bản | Kết quả đúng | Mức | Kết quả |
|---|---|---|---|---|---|
| 5.1 | KT | Tạo bảng lương kỳ thử cho cả công ty | Không lỗi công thức; NV lỗi được chỉ rõ biến và lý do | Chặn | |
| 5.2 | KT | So 10 phiếu (đủ loại: lương cao vượt trần BH, có người phụ thuộc, vào làm giữa kỳ, có phụ lục tăng lương) với bảng lương cũ | Thuế TNCN theo biểu 2026, BH có trần / sàn, giảm trừ gia cảnh đúng | Chặn | |
| 5.3 | KT | Duyệt bảng lương có phiếu của chính mình | Phiếu của mình bị chặn, người khác duyệt | Chặn | |
| 5.4 | KT | Chỉnh tay thưởng một phiếu → tính lại | GROSS / NET / tổng khấu trừ cập nhật; nhật ký ghi trước → sau | Thường | |
| 5.5 | NV A | Lương của tôi | Thấy phiếu đã duyệt của mình, số khớp màn KT; không thấy phiếu người khác | Chặn | |
| 5.6 | KT | Xuất Excel bảng lương, báo cáo chi phí lương (có BH công ty đóng) | Số khớp màn hình; tổng chi phí = GROSS + BH công ty | Thường | |

### 6. Báo cáo, nhật ký, cài đặt

| # | Vai trò | Kịch bản | Kết quả đúng | Mức | Kết quả |
|---|---|---|---|---|---|
| 6.1 | GĐ | Tổng quan | Số NV, đi muộn, nghỉ, lương kỳ gần nhất, HĐ / tài liệu sắp hết hạn hợp lý | Thường | |
| 6.2 | GĐ / HR | Báo cáo nhân sự, chấm công, lương, danh sách đóng BH, người phụ thuộc | Mở và xuất Excel được; QL chỉ xem phòng trong phạm vi | Thường | |
| 6.3 | HR | Nhật ký thao tác: lọc theo người / loại | Thấy các thao tác đã làm ở các mục trên (duyệt công, khoá kỳ, lương, đặt lại mật khẩu, duyệt sửa hồ sơ…) | Thường | |
| 6.4 | HR | Cài đặt công ty: vùng lương tối thiểu, lịch làm việc (T7 nửa ngày cho một phòng), số ngày báo trước HĐ | Công chuẩn kỳ sau tính theo lịch | Thường | |
| 6.5 | Mọi người | Đổi ngôn ngữ English, giao diện tối | Không còn chữ Việt / mã lỗi thô ở chế độ English; các màn đọc rõ ở chế độ tối | Thường | |

## Ký nghiệm thu

| Vai trò | Người thử | Ngày | Số mục ✘ (Chặn / Thường) | Đồng ý go-live |
|---|---|---|---|---|
| HR | | | | |
| QL | | | | |
| KT | | | | |
| NV | | | | |
| GĐ | | | | |
