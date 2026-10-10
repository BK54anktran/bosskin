---
title: Bảng lương
group: Kế toán
who: Kế toán, quản trị
summary: Bậc lương, biến số, công thức; tạo phiếu lương theo kỳ, chỉnh tay, duyệt, đánh dấu đã trả, xuất phiếu lương.
---

Mở **Bảng lương**. Bốn tab: **Bảng lương**, **Bậc lương**, **Biến số**, **Công thức lương**. Thiết lập một lần ở ba tab sau, rồi hằng tháng
chỉ cần tạo – kiểm tra – duyệt – trả ở tab đầu.

## Bậc lương

Mỗi bậc là một nhóm cách trả lương: **theo ngày** hoặc **theo giờ**, kèm đơn giá. Nhân viên gắn với một bậc (ở hồ sơ).

![Bậc lương](img:salary-grades)

## Biến số

Biến tự định nghĩa (thưởng chuyên cần, hệ số…) dùng trong công thức. Ngoài ra có sẵn **biến hệ thống** do BossKin tính từ dữ liệu:

| Biến | Ý nghĩa |
|---|---|
| `STANDARD_WORK_DAYS`, `PRESENT_DAYS` | Công chuẩn của kỳ, ngày công thực tế |
| `PAID_LEAVE_DAYS`, `UNPAID_LEAVE_DAYS`, `LATE_IN_DAYS` | Ngày nghỉ có / không lương, số ngày đi muộn |
| `DAY_HOURS`, `NIGHT_HOURS`, `DAY_OT`, `NIGHT_OT`, `TOTAL_OT_HOURS` | Giờ ca ngày / đêm, giờ tăng ca |
| `CONTRACT_SALARY`, `ALLOWANCE_<mã>` | Lương và phụ cấp theo hợp đồng / phụ lục hiệu lực trong kỳ |
| `INSURANCE_BASE`, `SOCIAL_INS`, `HEALTH_INS`, `UNEMPLOYMENT_INS`, `TOTAL_INSURANCE` | Lương đóng BH (đã áp sàn / trần) và từng khoản BH người lao động đóng |
| `PIT` | Thuế TNCN tính theo biểu hiện hành |
| `PERSONAL_DEDUCTION`, `DEPENDENTS`, `FAMILY_DEDUCTION` | Giảm trừ bản thân, số người phụ thuộc, tổng giảm trừ gia cảnh |
| `HOLIDAY_DAYS`, `HOLIDAY_OT_HOURS` | Ngày lễ hưởng lương, giờ làm ngày lễ |

![Biến số](img:salary-variables)

## Công thức lương

Mỗi bậc lương có công thức **GROSS** (tổng lương) và **NET** (thực nhận), hiệu lực từ một ngày. Viết bằng biến, phép tính, `IF(...)`,
`ROUND(...)`, `PIT_VN(thu nhập tính thuế)`. Ví dụ:

```
GROSS:  CONTRACT_SALARY * PRESENT_DAYS / STANDARD_WORK_DAYS + CONTRACT_ALLOWANCE + BONUS
NET:    GROSS - TOTAL_INSURANCE - PIT
```

![Công thức lương](img:salary-formulas)

> **Lưu ý:** Mức giảm trừ gia cảnh, biểu thuế và trần bảo hiểm do quản trị hệ thống cập nhật theo luật (theo ngày hiệu lực); kỳ lương dùng
> chính sách hiệu lực ở **ngày cuối kỳ**. Đừng viết cứng các con số này vào công thức.

## Tạo bảng lương tháng

1. Đảm bảo công của kỳ đã **duyệt** và (nên) **khoá kỳ công**.
2. Tab **Bảng lương** → **Tạo phiếu lương**.
3. Chọn **Tháng / Năm**; để trống ô nhân viên để tạo cho mọi người trong phạm vi, hoặc tìm và thêm từng người → **Tạo**.

![Tạo phiếu lương](img:payroll-generate)

Công thức lỗi với ai thì hệ thống báo rõ tên người và biến gây lỗi.

## Kiểm tra, chỉnh, duyệt, trả

Danh sách phiếu theo tháng hiện lương cơ bản, tổng lương gộp, thực nhận, ngày công và trạng thái **Nháp → Đã duyệt → Đã thanh toán**.

![Bảng lương tháng 9](img:payroll-list)

- **Xem chi tiết** — đầy đủ từng khoản. Phiếu nháp có thể nhập thưởng / khoản trừ tay rồi **tính lại**.
- Chọn nhiều phiếu (ô vuông bên phải) để **duyệt** hoặc **đánh dấu đã trả** hàng loạt.
- **Xuất phiếu lương** ra Excel (có cột BH công ty đóng và tổng chi phí).

> **Quan trọng:** Không ai tự duyệt, sửa hay trả phiếu lương của chính mình — người khác phải làm. Nhân viên chỉ thấy phiếu từ khi đã duyệt.
