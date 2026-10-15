# Nghiệp vụ

Hướng dẫn thao tác cho người dùng ở trang trợ giúp (`help/`). Sơ đồ luồng có hình ở
[review 10/2026 — luồng nghiệp vụ](../review-2026-10/luong-nghiep-vu.html). Trang này tóm các quy tắc mà code phải giữ.

## Luồng tổng

```mermaid
flowchart LR
  NV[Nhân viên<br/>+ hợp đồng] --> CA[Ca làm<br/>+ phân ca]
  LICH[Lịch tuần<br/>+ ngày lễ] --> CA
  CA --> CC[Check-in / out]
  CC --> CONG[Bảng công<br/>tính tức thời]
  YC[Yêu cầu chấm công] --> CONG
  PHEP[Đơn nghỉ phép] --> CONG
  CONG -->|duyệt, khoá kỳ| LUONG[Bảng lương<br/>công thức]
  HD[Hợp đồng, phụ lục,<br/>người phụ thuộc, thuế/BH] --> LUONG
  LUONG -->|duyệt| PHIEU[Phiếu lương NV]
```

## Module

| Module | Bảng chính | Quy tắc đáng nhớ |
|---|---|---|
| Công ty | `companies` | System admin tạo / sửa ở `/admin/companies`. Mã công ty 2–12 ký tự `[A-Z][A-Z0-9]`, không trùng và không là tiền tố của mã công ty khác (để mã NV không trùng giữa công ty), **không đổi** sau khi tạo (`error.company.code_immutable`). Đuôi email (`domain`) bắt buộc, unique (V22); đổi đuôi chỉ khi mọi tài khoản đã theo đuôi mới (`error.company.domain_accounts_mismatch`). Các danh mục khác (phòng ban, ca, loại phép, bậc lương…) mã unique theo công ty, mọi tra cứu theo mã / id đều lọc `company_id` của người gọi — không cần tiền tố |
| Nhân viên | `employees`, `employee_code_counters`, `employee_job_histories` | Mã NV = mã công ty + 5 số (`TH00001`), cấp từ bộ đếm, không tái dùng sau khi xoá; mã nhập tay (Excel) phải bắt đầu bằng mã công ty. Email tài khoản phải theo đuôi email công ty (`companies.domain`, V22 — `core/CompanyIdentity`). Chuyển phòng / chức vụ / lương / quản lý qua quá trình công tác, mốc tương lai áp lúc 00:05 ngày hiệu lực. Nghỉ việc (`POST /employees/{id}/resign`, ngày làm cuối ≤ hôm nay và ≥ ngày vào làm) **không xoá**: INACTIVE + `leave_date`, khoá tài khoản, gỡ quản lý trực tiếp của cấp dưới, gỡ phân ca sau ngày nghỉ chưa có công; `/reinstate` cho đi làm lại. `DELETE /employees/{id}` (xoá mềm, ẩn khỏi mọi danh sách) chỉ cho hồ sơ tạo nhầm, FE không còn nút gọi |
| Phòng ban, chức vụ | `departments`, `positions` | Cây phòng ban chặn vòng lặp, `level` tính lại khi đổi cha; nhập Excel 2 lượt (tạo rồi gắn cha) |
| Hồ sơ tự phục vụ | `profile_edit_requests`, `employee_dependents`, `employee_documents` | Nhân viên gửi yêu cầu sửa; người duyệt thấy giá trị cũ → mới (lưu lúc duyệt) |
| Hợp đồng | `labor_contracts`, `contract_appendices`, `contract_allowances` | Thời hạn kiểm theo loại HĐ; mỗi NV tối đa một HĐ hiệu lực; phụ lục tăng lương có ngày hiệu lực → lương tính theo phần ngày trong kỳ |
| Ca làm | `work_shifts`, `department_shifts`, `shift_assignments`, `shift_rotations`, `shift_swap_requests` | Ca cố định / linh hoạt / qua đêm / ca gãy; phân ca chặn chồng giờ; xoay ca bỏ ngày lễ và giữ ngày đã có công; không xoá phân ca đã có check-in/out, đã duyệt công, có đơn chấm công chờ duyệt (`error.shiftAssignment.has_pending_request`) hoặc đơn đã duyệt đang áp dụng — đơn bị từ chối / đã huỷ / đã tắt áp dụng không chặn |
| Đăng ký lịch (V23) | `shift_registration_rounds`, `shift_registration_round_departments`, `shift_registrations`, `companies.shift_registration_enabled` | Công ty bật / tắt. Quản lý (`SHIFT_REGISTRATION_MANAGE` + `SHIFT_VIEW`, phạm vi phòng ban) tạo đợt ≤ 62 ngày cho phòng ban, mở / đóng, hạn chót tự đóng (job 5 phút); hai đợt cùng phòng không chồng ngày. Nhân viên (`SHIFT_REGISTRATION_SELF`) đăng ký từng ngày: ca có sẵn / giờ tuỳ chỉnh / rảnh cả ngày, ≤ 2 khung, không chồng giờ, giới hạn giờ của đợt chỉ áp cho giờ tuỳ chỉnh. Duyệt theo ngày hoặc từng ô → `WorkShiftService.assign` (mỗi ô một giao dịch, lỗi trả lại); rảnh cả ngày cần quản lý chọn ca; không tự duyệt của mình |
| Chấm công | `attendances`, `attendance_requests`, `attendance_period_locks`, `employee_locations` | Giờ sửa tay lưu đủ **ngày + giờ** (`override_check_in/out` kiểu `datetime`, V27); giờ công = hiệu số thật ra − vào, hợp lệ trong (0, 24 giờ). Nhập chỉ HH:mm thì `core/AttendanceTimes` chọn ngày (có ca: theo khung ca; không ca: ra ≤ vào → +1 ngày; ngoài khoảng → `error.attendance.override_range_invalid`). API dòng bảng công trả giờ vào / ra (cả bản sửa tay) dạng `yyyy-MM-ddTHH:mm` đủ ngày; app so với ngày công để hiện "+N" nhỏ phía trên giờ. Công tính tức thời từ giờ vào / ra + ca + dung sai, chỉ lưu khi duyệt. Kỳ khoá thì mọi sửa bị chặn. Vị trí: bán kính công ty hoặc phòng; thiết bị gắn theo NV. Cài đặt `check_in_without_shift` (V25): ngày không có ca vẫn tự chấm vào / ra nhiều lượt (mỗi cặp một dòng, `attendances.punch_no`, V28), công không gắn ca, không xét đi muộn |
| Nghỉ phép | `leave_types`, `leave_grants`, `leave_ledger_entries`, `leave_requests`, `leave_accrual_rules` | Chỉ trừ ngày có ca, bỏ ngày lễ và giờ nghỉ trưa. Sổ trừ / hoàn ghi đúng quỹ đã trừ; huỷ / từ chối hoàn lại |
| Lịch | `work_calendars`, `holidays` (`company_id` trống = mẫu hệ thống) | Lịch tuần 7 ký tự (`F` cả ngày, `H` nửa ngày, `O` nghỉ) theo phòng, phòng con kế thừa. Ngày lễ: mẫu hệ thống → chép riêng khi công ty sửa năm đó |
| Lương | `salary_grades`, `salary_histories`, `formula_variables`, `salary_formulas`, `payrolls`, `tax_policies` | Kỳ theo ngày chốt; công thức có biến hệ thống + biến tự định nghĩa; thuế / BH theo chính sách hiệu lực ở **ngày cuối kỳ**; phiếu lưu snapshot; không tự duyệt phiếu của mình; bậc lương (và chức vụ) còn NV hoặc quá trình công tác dùng không xoá được (`error.salary_grade.in_use`, `error.position.in_use`) — xoá mềm khi còn liên kết làm nạp NV lỗi 500 |
| Báo cáo | (đọc) | Tổng quan, nhân sự, chấm công, lương, danh sách đóng BH; luôn lọc theo phạm vi |
| Excel | `excel_history` | Xuất / xem trước / nhập theo lệnh, thứ tự module theo phụ thuộc, file kết quả có dòng lỗi |
| Nhật ký | `audit_logs` | Chỉ ghi thêm; ghi cả lần xem tài liệu nhạy cảm |

## Biến lương hệ thống

Định nghĩa ở `PayrollService` / `FormulaEngine`; danh sách đầy đủ cho người dùng ở trang trợ giúp *Bảng lương*.

| Nhóm | Biến |
|---|---|
| Công | `STANDARD_WORK_DAYS`, `PRESENT_DAYS`, `ABSENT_DAYS`, `LEAVE_DAYS`, `PAID_LEAVE_DAYS`, `UNPAID_LEAVE_DAYS`, `LATE_IN_DAYS`, `EARLY_OUT_DAYS`, `ON_TIME_DAYS`, `OVERTIME_DAYS` |
| Giờ | `DAY_HOURS`, `NIGHT_HOURS`, `DAY_OT`, `NIGHT_OT`, `TOTAL_OT_HOURS`, `HOURS_PER_DAY`, `BASE_RATE` |
| Hợp đồng | `CONTRACT_SALARY`, `CONTRACT_ALLOWANCE`, `ALLOWANCE_<mã>`, `TAXABLE_ALLOWANCE`, `NON_TAXABLE_ALLOWANCE` |
| Bảo hiểm | `INSURANCE_SALARY`, `INSURANCE_BASE`, `INSURANCE_CAP`, `INSURANCE_FLOOR`, `UNEMPLOYMENT_BASE`, `UNEMPLOYMENT_CAP`, `SOCIAL_INS`, `HEALTH_INS`, `UNEMPLOYMENT_INS`, `TOTAL_INSURANCE` |
| Thuế | `PERSONAL_DEDUCTION`, `DEPENDENT_DEDUCTION`, `DEPENDENTS`, `FAMILY_DEDUCTION`, `PIT`, hàm `PIT_VN(x)` |
| Khác | `HOLIDAY_DAYS`, `HOLIDAY_OT_HOURS`, `TENURE_DAYS`, `TENURE_MONTHS`, `TENURE_YEARS`, `GROSS`, `BONUS`, `OTHER_DEDUCTIONS` |

Thêm biến hệ thống mới: khai báo trong `PayrollService`, thêm vào danh sách gợi ý ở FE, cập nhật bảng trên và trang trợ giúp *Bảng lương*.
