---
title: Cài đặt công ty
group: Quản trị
who: Quản trị công ty
summary: Chấm công, phép, người duyệt đơn, cảnh báo hợp đồng, lương và bảo hiểm, vị trí chấm công, lịch làm việc tuần, ngày lễ.
---

Mở **Cài đặt công ty** (cuối menu). Hai tab: **Chung** và **Lịch làm việc**.

## Tab Chung

![Thiết lập chấm công, phép, người duyệt](img:settings-general)

| Mục | Ý nghĩa |
|---|---|
| Phân biệt ngày / đêm, Bật chế độ OT | Tách giờ ca đêm; cho phép đăng ký tăng ca |
| Thiết lập phép | 1 ngày phép = bao nhiêu giờ (cho đơn nghỉ theo giờ) |
| **Người duyệt đơn** | *Theo quyền và phạm vi* (mặc định) hoặc *Quản lý trực tiếp duyệt trước, rồi HR* |
| Báo trước hợp đồng hết hạn | Số ngày (mặc định 30) — hợp đồng / tài liệu hết hạn trong số ngày này hiện cảnh báo |

![Lương và bảo hiểm](img:settings-general-2)

| Mục | Ý nghĩa |
|---|---|
| Công chuẩn theo lịch làm việc | Bật: công chuẩn mỗi kỳ đếm theo lịch tuần của phòng ban và ngày lễ. Tắt: dùng số cố định bên dưới |
| Số ngày công tiêu chuẩn / tháng | Mặc định 22 |
| Ngày chốt lương | Ngày bắt đầu kỳ (1–28). VD 25 → kỳ tháng 5 là 25/4–24/5 |
| Vùng lương tối thiểu | Vùng I–IV, dùng để tính trần bảo hiểm thất nghiệp và sàn lương đóng BH |
| Tỷ lệ BH công ty đóng | BHXH 17,5% · BHYT 3% · BHTN 1% (hiện ở báo cáo chi phí, không trừ vào lương) |

![Vị trí chấm công và thiết bị](img:settings-general-3)

| Mục | Ý nghĩa |
|---|---|
| Bật kiểm tra vị trí check-in | Bắt nhân viên đứng trong bán kính quanh vị trí công ty (hoặc vị trí riêng của phòng ban) |
| Chỉ chấm công trên thiết bị đã gắn | Lần chấm đầu tự gắn máy; máy khác bị chặn. Đổi máy: nhân sự gỡ thiết bị ở hồ sơ nhân viên |
| Phạm vi giờ check-in / out | Được chấm sớm / muộn bao nhiêu phút quanh giờ ca |

Nhớ bấm **Lưu** cuối trang.

## Tab Lịch làm việc

![Lịch làm việc tuần và ngày lễ](img:settings-calendar)

### Lịch tuần

Mỗi lịch quy định từng thứ: **làm cả ngày**, **nửa ngày** hay **nghỉ**. *Lịch mặc định* áp cho mọi phòng chưa gán lịch riêng.

1. Bấm **Thêm lịch**, đặt tên (vd. "Xưởng: T7 làm sáng").
2. Bấm vào từng thứ để đổi cả ngày → nửa ngày → nghỉ.
3. Tích các **phòng ban** dùng lịch này → **Lưu**. Phòng con chưa gán lịch dùng lịch của phòng cha.

![Thêm lịch làm việc](img:calendar-new)

### Ngày lễ

Danh sách theo năm (mũi tên đổi năm). Mặc định công ty dùng **mẫu hệ thống** (Tết Dương lịch, Tết Âm lịch, Giỗ Tổ, 30/4, 1/5, 2/9…).
Lần đầu bạn thêm / sửa / xoá một ngày của năm nào, mẫu năm đó được chép thành danh sách riêng của công ty.

- **Thêm ngày lễ**: ngày, tên, loại (*Ngày lễ*, *Nghỉ bù*, *Làm bù*), có hưởng lương không.
- **Xuất / Nhập Excel** để nhập lịch nghỉ Tết theo thông báo hằng năm (có xem trước).

Ảnh hưởng: đơn nghỉ không tính ngày lễ, lưới phân ca và bảng công tô màu ngày lễ, lương có `HOLIDAY_DAYS` (lễ hưởng lương) và
`HOLIDAY_OT_HOURS` (giờ làm ngày lễ).
