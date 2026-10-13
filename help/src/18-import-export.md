---
title: Import / Export Excel
group: Quản trị
who: Quản trị, nhân sự
summary: Xuất dữ liệu nhiều module ra một file, sửa rồi nhập lại với bước xem trước; nhập dữ liệu ban đầu khi bắt đầu dùng.
---

Mở **Import / Export**.

![Màn Import / Export](img:excel)

## Xuất dữ liệu

1. Tích các module cần xuất (nhân viên, phòng ban, chức vụ, ca, phân công ca, chấm công, bậc lương, công thức, biến, bảng lương,
   loại nghỉ phép, số dư phép). Bỏ trống = xuất tất cả.
2. Bấm **Chọn & Xuất**. File Excel có mỗi module một sheet; cột đầu là **Lệnh**.

Cột chữ (SĐT, CCCD, số tài khoản…) đã định dạng Text nên gõ số 0 ở đầu vẫn giữ nguyên.

## Tải file mẫu (nhập dữ liệu lần đầu)

Công ty mới chưa có dữ liệu để xuất ra làm mẫu: bấm **Tải file mẫu** ở khung **Nhập dữ liệu**.

![Nút Tải file mẫu ở khung Nhập dữ liệu](img:excel-template)

- Mỗi loại dữ liệu một sheet, **chỉ có dòng tiêu đề** đúng các cột nhập được.
- Sheet cuối **Hướng dẫn** liệt kê từng cột: bắt buộc hay không, **ví dụ** và ghi chú (định dạng ngày `dd/MM/yyyy`, giờ `HH:mm`,
  mã tham chiếu lấy ở đâu…). File mở sẵn ở sheet này.
- Điền từ dòng 2, ghi `MERGE` ở cột **Lệnh** cho mỗi dòng cần nhập. Nhân viên mới để trống **Mã NV**, hệ thống tự cấp.
- Điền được cả phòng ban lẫn nhân viên thuộc phòng ban đó trong **cùng một file**: bản xem trước hiểu phòng ban sẽ được tạo trước.

Màn **Hợp đồng** và **Cài đặt công ty → Lịch làm việc** (ngày lễ) cũng có nút **Tải file mẫu** riêng cạnh **Nhập Excel**.

## Nhập dữ liệu

1. Mở file đã xuất (hoặc mẫu), sửa / thêm dòng. Ở cột **Lệnh** ghi `CREATE` (thêm), `UPDATE` (sửa), `MERGE` (thêm hoặc sửa theo mã) hoặc `DELETE` (xoá).
   Dòng để trống cột **Lệnh** bị bỏ qua.
2. Ở khung **Nhập dữ liệu**, chọn file `.xlsx`.
3. BossKin hiện **xem trước** từng dòng: tạo mới, cập nhật (kèm giá trị cũ → mới), xoá, cảnh báo, lỗi.
4. Kiểm tra rồi **xác nhận**. Tải **file kết quả** để xem dòng lỗi, sửa và nhập lại — nhập lại cùng file không tạo trùng.

Xem trước chỉ hiện **dòng có thay đổi**: nhập lại nguyên file vừa xuất sẽ báo không có gì thay đổi. File xuất ở giao diện tiếng Anh
hay tiếng Việt đều nhập lại được.

Thứ tự nhập tự động theo phụ thuộc: phòng ban → chức vụ → bậc lương → ca → loại phép → biến → công thức → nhân viên → số dư phép → phân ca →
chấm công → lương.

> **Lưu ý:** Tài khoản nhân viên tạo từ Excel có mật khẩu ngẫu nhiên. Nhập xong, vào **Phân quyền → Người dùng → Xuất mật khẩu tạm**
> để lấy file mật khẩu phát cho nhân viên.

Phần **Lịch sử** cuối trang ghi các lần xuất / nhập, lọc theo loại, module, ngày.

Các màn khác (Nhân viên, Hợp đồng, Ca làm, Chấm công, Ngày lễ…) cũng có nút **Xuất Excel / Nhập Excel** riêng, cùng cách làm: luôn
xem trước trước khi nhập.
