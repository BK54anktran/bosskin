<!-- Tự sinh bởi tools/docs/gen_he_thong.py — không sửa tay; sửa code rồi chạy lại. -->

# Danh mục quyền

48 mã quyền (bảng `permissions`, thêm bằng migration). Vai trò của công ty gom một tập quyền + phạm vi phòng ban; cách kiểm tra quyền và phạm vi ở [phân quyền](phan-quyen.md). **Cần** = quyền phải có kèm (`required_rule`), màn Phân quyền tự tích theo. Cột **Endpoint** đếm số API kiểm mã này trực tiếp ở controller.


## ATTENDANCE

| Mã | Mô tả | Cần | Endpoint | Dùng ở FE |
|---|---|---|---|---|
| `ATTENDANCE_VIEW` | Xem dữ liệu chấm công |  | 20 | attendance_day_tab, attendance_requests_screen, attendance_screen, attendance_ti |
| `ATTENDANCE_MANAGE` | Chỉnh sửa chấm công | `ATTENDANCE_VIEW` | 14 | attendance_screen, nav_access, permission_labels |
| `ATTENDANCE_SELF` | Tự check-in/check-out | `ATTENDANCE_VIEW` | 15 | app_shell, nav_access, permission_labels, shift_swap_screen |
| `ATTENDANCE_REQUEST_APPROVE` | Duyệt yêu cầu chấm công | `ATTENDANCE_VIEW` | 8 | attendance_requests_screen, audit_log_screen, nav_access, permission_labels |
| `ATTENDANCE_APPROVE` | Duyệt / bỏ duyệt bảng công | `ATTENDANCE_VIEW` | 4 | attendance_day_tab, attendance_screen, audit_log_screen, permission_labels |
| `ATTENDANCE_PERIOD_LOCK` | Khoá / mở lại kỳ công | `ATTENDANCE_VIEW` | 2 | attendance_screen, permission_labels |

## CALENDAR

| Mã | Mô tả | Cần | Endpoint | Dùng ở FE |
|---|---|---|---|---|
| `CALENDAR_VIEW` | Xem ngày lễ và lịch làm việc |  | 15 | company_settings_screen, nav_access, permission_labels, work_calendar_tab |
| `CALENDAR_MANAGE` | Sửa ngày lễ và lịch làm việc | `CALENDAR_VIEW` | 10 | permission_labels, work_calendar_tab |

## COMPANY

| Mã | Mô tả | Cần | Endpoint | Dùng ở FE |
|---|---|---|---|---|
| `COMPANY_MANAGE` | Toàn quyền quản trị công ty |  |  | permission_labels |
| `AUDIT_VIEW` | Xem nhật ký thao tác |  | 1 | nav_access, permission_labels |

## COMPANY_SETTING

| Mã | Mô tả | Cần | Endpoint | Dùng ở FE |
|---|---|---|---|---|
| `COMPANY_SETTING_VIEW` | Xem cài đặt chung công ty |  |  | company_settings_screen, nav_access, permission_labels |
| `COMPANY_SETTING_MANAGE` | Quản lý cài đặt chung công ty |  | 1 | permission_labels |

## CONTRACT

| Mã | Mô tả | Cần | Endpoint | Dùng ở FE |
|---|---|---|---|---|
| `CONTRACT_VIEW` | Xem hợp đồng lao động |  | 15 | contract_dialogs, employee_documents_dialog, nav_access, permission_labels |
| `CONTRACT_EDIT` | Tạo / sửa hợp đồng lao động và phụ lục | `CONTRACT_VIEW` | 10 | contract_dialogs, contracts_screen, permission_labels |
| `CONTRACT_DELETE` | Xoá hợp đồng lao động | `CONTRACT_VIEW` | 1 | audit_log_screen, contract_dialogs, permission_labels |

## DASHBOARD

| Mã | Mô tả | Cần | Endpoint | Dùng ở FE |
|---|---|---|---|---|
| `DASHBOARD_VIEW` | Hiển thị mục Tổng quan trên menu |  | 6 | app_shell, nav_access, permission_labels |

## DEPARTMENT

| Mã | Mô tả | Cần | Endpoint | Dùng ở FE |
|---|---|---|---|---|
| `DEPARTMENT_VIEW` | Xem cơ cấu phòng ban |  | 10 | department_service, nav_access, permission_labels, roles_screen |
| `DEPARTMENT_MANAGE` | Tạo/sửa/xóa phòng ban | `DEPARTMENT_VIEW` | 7 | department_screen, permission_labels |
| `POSITION_MANAGE` | Tạo/sửa/xóa chức vụ | `DEPARTMENT_VIEW` | 3 | permission_labels |

## EMPLOYEE

| Mã | Mô tả | Cần | Endpoint | Dùng ở FE |
|---|---|---|---|---|
| `EMPLOYEE_VIEW` | Xem danh sách nhân viên |  | 17 | employee_screen, nav_access, permission_labels, roles_screen |
| `EMPLOYEE_CREATE` | Thêm nhân viên mới | `EMPLOYEE_VIEW` | 3 | employee_screen, permission_labels |
| `EMPLOYEE_UPDATE` | Cập nhật thông tin nhân viên | `EMPLOYEE_VIEW` | 10 | auth_service, dependents_dialog, edit_requests_screen, employee_screen, job_hist |
| `EMPLOYEE_DELETE` | Xóa/vô hiệu hóa nhân viên | `EMPLOYEE_VIEW` | 3 | employee_screen, permission_labels |
| `EMPLOYEE_SENSITIVE_VIEW` | Xem dữ liệu nhạy cảm của nhân viên (CCCD, tài khoản NH, MST, sổ BHXH) | `EMPLOYEE_VIEW` |  | permission_labels |
| `EMPLOYEE_DOCUMENT_VIEW` | Xem tài liệu nhân sự của nhân viên | `EMPLOYEE_VIEW` | 13 | employee_screen, nav_access, permission_labels |
| `EMPLOYEE_DOCUMENT_EDIT` | Tải lên / sửa / xoá / duyệt tài liệu nhân sự, cấu hình loại tài liệu | `EMPLOYEE_DOCUMENT_VIEW` | 8 | documents_screen, employee_documents_dialog, permission_labels |

## EXCEL

| Mã | Mô tả | Cần | Endpoint | Dùng ở FE |
|---|---|---|---|---|
| `EXCEL_EXPORT` | Xuất Excel tổng hợp (theo quyền từng module) |  | 5 | nav_access, permission_labels |
| `EXCEL_IMPORT` | Nhập Excel tổng hợp (theo quyền từng module) |  | 7 | excel_import_export_screen, nav_access, permission_labels |

## LEAVE

| Mã | Mô tả | Cần | Endpoint | Dùng ở FE |
|---|---|---|---|---|
| `LEAVE_VIEW` | Xem đơn nghỉ và số phép |  | 9 | app_shell, leaves_screen, nav_access, permission_labels, roles_screen |
| `LEAVE_REQUEST_CREATE` | Tạo đơn nghỉ | `LEAVE_VIEW` | 1 | leaves_screen, permission_labels |
| `LEAVE_REQUEST_APPROVE` | Duyệt/Từ chối đơn nghỉ | `LEAVE_VIEW` | 3 | leaves_screen, permission_labels |
| `LEAVE_TYPE_MANAGE` | Quản lý loại nghỉ | `LEAVE_TYPE_VIEW` | 3 | leaves_screen, permission_labels |
| `LEAVE_GRANT_MANUAL` | Cấp phép thủ công | `LEAVE_VIEW` | 1 | leaves_screen, permission_labels |
| `LEAVE_ACCRUAL_MANAGE` | Quản lý rule cộng phép tự động | `LEAVE_ACCRUAL_VIEW` | 5 | leaves_screen, permission_labels |
| `LEAVE_TYPE_VIEW` | Xem danh sách loại nghỉ | `LEAVE_VIEW` |  | leaves_screen, permission_labels |
| `LEAVE_ACCRUAL_VIEW` | Xem cài đặt rule cộng phép | `LEAVE_VIEW` |  | leaves_screen, permission_labels |
| `LEAVE_REQUEST_CREATE_FOR_OTHERS` | Tạo đơn nghỉ phép hộ nhân viên khác | `LEAVE_REQUEST_CREATE` |  | leaves_screen, permission_labels |

## PAYROLL

| Mã | Mô tả | Cần | Endpoint | Dùng ở FE |
|---|---|---|---|---|
| `PAYROLL_VIEW` | Xem bảng lương |  | 20 | nav_access, payroll_screen, permission_labels, roles_screen |
| `PAYROLL_CREATE` | Tạo bảng lương | `PAYROLL_VIEW` | 17 | employee_screen, payroll_screen, permission_labels, salary_formula_tab, salary_g |
| `PAYROLL_APPROVE` | Phê duyệt bảng lương | `PAYROLL_VIEW` | 1 | audit_log_screen, payroll_screen, permission_labels |
| `PAYROLL_PAY` | Đánh dấu đã thanh toán lương | `PAYROLL_VIEW` | 1 | audit_log_screen, payroll_screen, permission_labels |

## REPORT

| Mã | Mô tả | Cần | Endpoint | Dùng ở FE |
|---|---|---|---|---|
| `REPORT_VIEW` | Xem và xuất báo cáo nhân sự |  | 11 | nav_access, permission_labels |

## ROLE

| Mã | Mô tả | Cần | Endpoint | Dùng ở FE |
|---|---|---|---|---|
| `ROLE_VIEW` | Xem danh sách vai trò |  | 1 | nav_access, permission_labels, roles_screen |
| `ROLE_MANAGE` | Tạo/sửa/xóa vai trò | `ROLE_VIEW` | 7 | department_screen, permission_labels, roles_screen |

## SHIFT

| Mã | Mô tả | Cần | Endpoint | Dùng ở FE |
|---|---|---|---|---|
| `SHIFT_VIEW` | Xem ca làm |  | 10 | nav_access, permission_labels, roles_screen, shift_screen |
| `SHIFT_MANAGE` | Quản lý ca làm | `SHIFT_VIEW` | 24 | nav_access, permission_labels, shift_assign_tab, shift_screen |
| `SHIFT_SWAP_APPROVE` | Duyệt yêu cầu đổi ca / nhường ca | `SHIFT_VIEW` | 1 | nav_access, permission_labels, shift_swap_screen |

## USER

| Mã | Mô tả | Cần | Endpoint | Dùng ở FE |
|---|---|---|---|---|
| `USER_MANAGE` | Quản lý tài khoản người dùng |  | 12 | employee_screen, permission_labels, roles_screen |

## Kiểm tra đồng bộ

- Mã quyền dùng trong code nhưng DB không có: không có ✔
- Mã quyền có trong DB nhưng không code nào dùng: không có ✔
