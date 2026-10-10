---
title: Hợp đồng lao động
group: Nhân sự
who: Nhân sự
summary: Tạo hợp đồng, phụ cấp, kích hoạt, phụ lục tăng lương, chấm dứt, theo dõi hợp đồng sắp hết hạn, xuất / nhập Excel.
---

## Danh sách hợp đồng

Mở **Hợp đồng lao động**. Tìm theo số HĐ, tên, mã NV, phòng ban; lọc trạng thái (Nháp, Hiệu lực, Hết hạn, Chấm dứt). Dải màu cam
phía trên báo số hợp đồng **sắp hết hạn hoặc đã quá hạn** mà chưa có hợp đồng nối tiếp — bấm vào để lọc nhanh.

![Danh sách hợp đồng](img:contracts)

Hợp đồng sắp hết hạn cũng hiện ở **Tổng quan → Cảnh báo & Rủi ro**, và người có quyền xem hợp đồng nhận thông báo khi còn N / 7 / 0 ngày
(N đặt ở Cài đặt công ty, mặc định 30).

## Tạo hợp đồng

1. Bấm **Thêm hợp đồng**.
2. Chọn **Nhân viên**, nhập **Số hợp đồng** (không trùng trong công ty).
3. Chọn **Loại hợp đồng**: thử việc, xác định thời hạn (tối đa 36 tháng), không xác định thời hạn, thời vụ / cộng tác.
4. Nhập ngày ký, **ngày hiệu lực**, ngày kết thúc (bỏ trống với HĐ không xác định thời hạn).
5. Nhập **Lương cơ bản**; **Lương đóng BH** để trống thì bằng lương + phụ cấp đóng BH.
6. **Thêm phụ cấp**: mã (A–Z, 0–9, _), tên, số tiền, có đóng BH / chịu thuế không. Mã phụ cấp dùng được trong công thức lương
   dưới dạng `ALLOWANCE_<mã>`.
7. Bấm **Lưu** — hợp đồng ở trạng thái **Nháp**.

![Thêm hợp đồng](img:contract-new)

Mở hợp đồng nháp → **Kích hoạt** để có hiệu lực. Hai hợp đồng không nháp của cùng một người không được chồng ngày.

## Phụ lục (tăng lương, đổi phụ cấp / chức danh)

1. Bấm vào hợp đồng → **Thêm phụ lục**.
2. Nhập số phụ lục, **ngày hiệu lực** và chỉ những ô thay đổi (ô để trống giữ giá trị cũ).
3. Bật **Thay bộ phụ cấp từ ngày này** nếu muốn thay cả danh sách phụ cấp → **Lưu**.

![Chi tiết hợp đồng](img:contract-detail)

![Thêm phụ lục](img:appendix-new)

Phụ lục có hiệu lực giữa tháng thì lương tháng đó được tính bình quân theo số ngày công của từng mức.

## Chấm dứt hợp đồng

Trong chi tiết hợp đồng bấm **Chấm dứt**, nhập ngày làm việc cuối và lý do. Hợp đồng chuyển sang *Chấm dứt*, không còn tính lương sau ngày đó.

## Xuất / nhập Excel

**Xuất Excel** tạo file 2 sheet (hợp đồng + phụ cấp). Sửa rồi **Nhập Excel** → xem trước từng dòng → xác nhận. Sheet phụ cấp vắng thì phụ
cấp hiện có được giữ nguyên.
