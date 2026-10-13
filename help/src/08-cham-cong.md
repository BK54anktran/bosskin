---
title: Bảng công, duyệt và khoá kỳ
group: Quản lý
who: Quản lý chấm công, nhân sự
summary: Xem công theo ngày / tuần / tháng, sửa và duyệt công, duyệt cả kỳ, duyệt yêu cầu chấm công, khoá kỳ công.
---

## Xem bảng công

Mở **Chấm công**. Có bốn cách xem:

- **Theo ngày** — mọi nhân viên trong một ngày: ca, giờ vào / ra, giờ nghỉ, tổng giờ, tăng ca, trạng thái.
- **Tuần** — lưới 7 ngày.
- **Theo tháng** — từng ngày của một nhân viên (chọn ở ô *Nhân viên*).
- **Khoảng thời gian** — tổng hợp nhiều ngày.

Lọc theo **phòng ban**; bạn chỉ thấy nhân viên trong phạm vi được cấp. Ngày lễ / ngày nghỉ theo lịch được tô màu.

![Chấm công theo ngày](img:att-day)

![Chấm công theo tháng của một nhân viên](img:att-month)

Trạng thái thường gặp: *Đúng giờ*, *Đi muộn*, *Về sớm* (theo dung sai phút của công ty / phòng ban), *Vắng*, *Nghỉ phép*.

## Sửa và duyệt từng dòng

Mỗi dòng có nút **sửa** (bút chì) để nhập / chỉnh giờ vào, giờ ra, ghi chú; nút **xoá**; và nút **duyệt** (dấu tích). Công phải được
duyệt mới vào bảng lương. Mọi lần sửa / duyệt / xoá đều ghi vào Nhật ký thao tác.

> **Lưu ý:** Không duyệt được ngày không có ca mà cũng không có dữ liệu chấm (tránh tạo bản ghi vắng sai).

## Duyệt cả kỳ

Duyệt một lần mọi ca chưa duyệt của cả phòng (hoặc cả công ty) trong một kỳ công.

1. Bấm **Duyệt cả kỳ**.
2. Chọn **Kỳ công** và **Phòng ban**.
3. Bấm **Duyệt**. Kết quả báo số dòng đã duyệt, đã duyệt từ trước, bỏ qua.

![Duyệt công cả kỳ](img:att-bulk-approve)

Chỉ duyệt các **ngày đã qua**; dòng chỉ có giờ vào hoặc chỉ có giờ ra bị bỏ lại để bạn kiểm tra và duyệt từng dòng.

## Duyệt yêu cầu chấm công

Mở **Yêu cầu chấm công** → tab **Chờ duyệt**. Mỗi yêu cầu hiện giờ đang có và giờ xin sửa. Bấm **Duyệt** hoặc **Từ chối**.

![Duyệt yêu cầu sửa giờ](img:att-requests-approve)

Bạn không tự duyệt được yêu cầu của chính mình.

## Khoá kỳ công

Sau khi chốt công tháng, khoá kỳ để không ai sửa được nữa (bảng lương tính trên số liệu đã chốt).

1. Bấm **Khoá kỳ công** — hộp hiện các kỳ trong năm.
2. Bấm **Khoá** ở kỳ cần chốt. Kỳ đã khoá có nút **Mở lại** (khi cần sửa sai).

![Khoá / mở kỳ công](img:att-lock)

Khi kỳ đã khoá: không sửa / xoá / duyệt công, không phân ca, không gửi yêu cầu chấm công cho ngày trong kỳ.

## Xuất / nhập Excel

**Xuất Excel** tải bảng công đang xem (theo tháng của cả phòng, theo tháng của một nhân viên, hoặc theo ngày). **Nhập Excel** cho phép
sửa giờ hàng loạt hoặc nhập giờ chấm từ máy chấm công cũ: luôn có bước **xem trước** từng dòng (tạo mới / cập nhật / lỗi) trước khi xác nhận.

Cách sửa nhanh nhất là **xuất → sửa → nhập lại chính file đó**:

1. Xuất bảng công đang xem.
2. Sửa các ô có dấu `*`: *Check-in*, *Check-out*, *Giờ giải lao*, *Tăng ca ngày / đêm* (dạng `HH:mm`), *Trạng thái duyệt* (`true` / `false`);
   ghi `x` ở cột *Xóa* để xoá công ngày đó. Các cột khác chỉ để tham khảo.
3. Nhập lại file. Xem trước chỉ liệt kê **những ô bạn đã sửa** (giá trị cũ → mới); dòng không sửa được bỏ qua, nhập lại nguyên file
   không thay đổi gì.

> **Mẹo:** File xuất bằng giao diện tiếng Anh vẫn nhập lại được khi đang dùng tiếng Việt và ngược lại. Ngày đã sửa mà đang duyệt sẽ được
> tính lại khi duyệt; kỳ công đã khoá thì không nhập được.
