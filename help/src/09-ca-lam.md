---
title: Ca làm và phân ca
group: Quản lý
who: Quản lý ca, nhân sự
summary: Tạo ca (cố định, linh hoạt, qua đêm), phân ca cho nhân viên, điền nhanh, mẫu xoay ca, duyệt đổi ca.
---

## Danh sách ca

Mở **Ca làm** → tab **Danh sách ca**. Mỗi ca có mã, giờ bắt đầu – kết thúc, giờ nghỉ giữa ca và số giờ làm.

![Danh sách ca](img:shift-list)

### Tạo ca mới

1. Bấm **Tạo ca mới**.
2. Nhập **Tên ca**, **Mã ca** (ngắn, hiện trên lưới phân ca), nhóm ca nếu muốn.
3. Chọn kiểu: **Giờ cố định** (vào – ra cố định) hoặc **Linh hoạt** (đủ số giờ trong một khung giờ; thiếu giờ tính là đi muộn).
4. Nhập giờ bắt đầu / kết thúc, giờ nghỉ (nếu có). Ca kết thúc sau 0 giờ được hiểu là **ca qua đêm**.
5. Chọn màu và phòng ban áp dụng → **Tạo ca mới**.

![Hộp tạo ca](img:shift-new)

## Phân công ca

Tab **Phân công ca** là lưới: dòng là nhân viên, cột là ngày trong kỳ (theo ngày chốt lương của công ty).

1. Chọn kỳ bằng mũi tên cạnh tháng; lọc phòng ban / tìm nhân viên nếu cần.
2. Bấm vào ô (nhân viên × ngày) để chọn ca; một ngày tối đa 4 ca, các ca không được chồng giờ.
3. **Điền nhanh ca**: mở bảng ca bên phải, chọn một ca rồi bấm vào nhiều ô liên tiếp để điền.

![Lưới phân công ca](img:shift-assign)

![Điền nhanh ca](img:shift-quickfill)

Ngày đã có dữ liệu chấm công (đã check-in/out, đã duyệt công, hoặc có đơn sửa giờ đã duyệt đang áp dụng) không xoá ca được. Còn đơn sửa giờ **chờ duyệt** thì duyệt hoặc từ chối đơn trước; đơn đã bị từ chối, đã huỷ hoặc đã tắt áp dụng (giờ bị gạch ngang trên bảng công) không cản việc xoá ca. **Xuất / Nhập Excel** dùng bảng ngang (nhân viên × ngày, ô là mã ca), có xem trước
trước khi nhập.

## Mẫu xoay ca

Cho tổ làm ca xoay vòng (vd. 6 ngày ca 1 – 6 ngày ca 2 – 2 ngày nghỉ).

1. Tab **Xoay ca** → **Thêm mẫu xoay**: đặt tên, độ dài chu kỳ, chọn ca cho từng ngày (để trống = nghỉ).
2. Bấm **Áp dụng cho nhân viên** trên mẫu: chọn nhân viên, ngày bắt đầu, độ lệch ngày của từng người và khoảng thời gian cần sinh.
3. Tuỳ chọn **Bỏ qua ngày lễ**. Ngày đã có chấm công được giữ nguyên.

![Mẫu xoay ca](img:shift-rotation)

## Duyệt đổi ca

Mở **Đổi ca** → lọc **Chờ duyệt**. Mỗi yêu cầu hiện ai đổi với ai, ca và ngày. Bấm **Duyệt** hoặc **Từ chối**.

![Duyệt yêu cầu đổi ca](img:swap-approve)
