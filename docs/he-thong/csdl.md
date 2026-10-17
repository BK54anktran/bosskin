<!-- Tự sinh bởi tools/docs/gen_he_thong.py — không sửa tay; sửa code rồi chạy lại. -->

# Cơ sở dữ liệu

MySQL 8, utf8mb4. Lược đồ tại migration **V31 – position common**, 53 bảng (không kể `flyway_schema_history`). Mọi thay đổi lược đồ đi qua file Flyway mới `backend/src/main/resources/db/migration/V<n>__<mô_tả>.sql`, không sửa file cũ; Hibernate chạy `ddl-auto: validate` nên entity lệch DB thì app không khởi động. Hầu hết bảng nghiệp vụ có `company_id` (tách dữ liệu theo công ty — xem [kiến trúc](kien-truc.md#da-cong-ty)).

Ký hiệu: 🔑 khoá chính · ↗ khoá ngoại (bảng.cột, hành vi khi xoá) · `∅` không có mặc định.

## Mục lục

- **Công ty & tài khoản**: [`companies`](#companies), [`fcm_notification_logs`](#fcm_notification_logs), [`permissions`](#permissions), [`role_permission_dept_scopes`](#role_permission_dept_scopes), [`role_permissions`](#role_permissions), [`roles`](#roles), [`system_admins`](#system_admins), [`trial_requests`](#trial_requests), [`user_permission_dept_scopes`](#user_permission_dept_scopes), [`user_permissions`](#user_permissions), [`user_roles`](#user_roles), [`user_sessions`](#user_sessions), [`users`](#users)
- **Tổ chức & nhân viên**: [`departments`](#departments), [`document_types`](#document_types), [`employee_code_counters`](#employee_code_counters), [`employee_dependents`](#employee_dependents), [`employee_documents`](#employee_documents), [`employee_job_histories`](#employee_job_histories), [`employee_locations`](#employee_locations), [`employees`](#employees), [`positions`](#positions), [`profile_edit_requests`](#profile_edit_requests)
- **Hợp đồng**: [`contract_allowances`](#contract_allowances), [`contract_appendices`](#contract_appendices), [`labor_contracts`](#labor_contracts)
- **Ca làm**: [`shift_assignments`](#shift_assignments), [`shift_registration_round_departments`](#shift_registration_round_departments), [`shift_registration_rounds`](#shift_registration_rounds), [`shift_registrations`](#shift_registrations), [`shift_rotations`](#shift_rotations), [`shift_swap_requests`](#shift_swap_requests), [`work_shifts`](#work_shifts)
- **Chấm công**: [`attendance_approve_leaves`](#attendance_approve_leaves), [`attendance_period_locks`](#attendance_period_locks), [`attendance_requests`](#attendance_requests), [`attendances`](#attendances)
- **Nghỉ phép**: [`leave_accrual_rules`](#leave_accrual_rules), [`leave_grants`](#leave_grants), [`leave_ledger_entries`](#leave_ledger_entries), [`leave_requests`](#leave_requests), [`leave_types`](#leave_types)
- **Lịch & ngày lễ**: [`holidays`](#holidays), [`work_calendars`](#work_calendars)
- **Lương & thuế**: [`formula_variables`](#formula_variables), [`payrolls`](#payrolls), [`salary_formulas`](#salary_formulas), [`salary_grades`](#salary_grades), [`salary_histories`](#salary_histories), [`tax_policies`](#tax_policies)
- **Nhật ký, Excel, khác**: [`audit_logs`](#audit_logs), [`department_shifts`](#department_shifts), [`excel_history`](#excel_history)

## Công ty & tài khoản

### companies

Duy nhất: (code) · (domain)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `name` | varchar(200) |  | ∅ |  |
| `code` | varchar(50) |  | ∅ |  |
| `domain` | varchar(100) | có | ∅ |  |
| `logo` | varchar(255) | có | ∅ |  |
| `address` | text | có | ∅ |  |
| `phone` | varchar(20) | có | ∅ |  |
| `email` | varchar(100) | có | ∅ |  |
| `active` | tinyint(1) |  | 1 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `day_start_time` | time |  | 06:00:00 |  |
| `day_end_time` | time |  | 22:00:00 |  |
| `self_attendance_enabled` | tinyint(1) |  | 1 |  |
| `attendance_day_night_mode` | tinyint(1) |  | 0 |  |
| `attendance_ot_enabled` | tinyint(1) |  | 1 |  |
| `leave_hours_per_day` | decimal(10,2) |  | 8.00 |  |
| `check_in_latitude` | double | có | ∅ |  |
| `check_in_longitude` | double | có | ∅ |  |
| `check_in_radius_meters` | int |  | 100 |  |
| `location_check_enabled` | tinyint(1) |  | 0 |  |
| `check_in_before_minutes` | int |  | 30 |  |
| `check_in_after_minutes` | int |  | 30 |  |
| `check_out_before_minutes` | int |  | 30 |  |
| `check_out_after_minutes` | int |  | 30 |  |
| `standard_work_days` | int |  | 22 |  |
| `payroll_cutoff_day` | int |  | 1 |  |
| `check_in_tolerance_minutes` | int | có | ∅ |  |
| `check_out_tolerance_minutes` | int | có | ∅ |  |
| `rounding_check_in_minutes` | int | có | ∅ |  |
| `rounding_check_out_minutes` | int | có | ∅ |  |
| `rounding_work_minutes` | int | có | ∅ |  |
| `device_binding_enabled` | tinyint(1) |  | 0 |  |
| `require_admin_2fa` | tinyint(1) |  | 0 |  |
| `min_wage_region` | int |  | 1 |  |
| `standard_days_from_calendar` | tinyint(1) |  | 0 |  |
| `approval_mode` | varchar(20) |  | PERMISSION |  |
| `contract_expiry_warning_days` | int |  | 30 |  |
| `employer_social_rate` | decimal(6,4) |  | 0.1750 |  |
| `employer_health_rate` | decimal(6,4) |  | 0.0300 |  |
| `employer_unemployment_rate` | decimal(6,4) |  | 0.0100 |  |
| `shift_registration_enabled` | tinyint(1) |  | 0 |  |
| `check_in_without_shift` | tinyint(1) |  | 0 |  |
| `disabled_features` | varchar(1000) | có | ∅ |  |

### fcm_notification_logs

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `user_id` | bigint |  | ∅ |  |
| `fcm_token` | varchar(512) |  | ∅ |  |
| `shift_name` | varchar(100) |  | ∅ |  |
| `shift_start` | time |  | ∅ |  |
| `work_date` | date |  | ∅ |  |
| `minutes_before` | int |  | ∅ |  |
| `status` | varchar(20) |  | ∅ | SUCCESS / FAILED |
| `error_message` | varchar(500) | có | ∅ |  |
| `sent_at` | datetime |  | ∅ |  |

### permissions

Duy nhất: (code)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `code` | varchar(50) |  | ∅ |  |
| `description` | varchar(200) |  | ∅ |  |
| `module` | varchar(50) |  | ∅ |  |
| `required_rule` | varchar(50) | có | ∅ |  |

### role_permission_dept_scopes

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `role_id` | bigint |  | ∅ | 🔑 ↗ [roles](#roles).id (cascade) |
| `permission_code` | varchar(50) |  | ∅ | 🔑 |
| `department_id` | bigint |  | ∅ | 🔑 |

### role_permissions

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `role_id` | bigint |  | ∅ | 🔑 ↗ [roles](#roles).id (cascade) |
| `permission_id` | bigint |  | ∅ | 🔑 ↗ [permissions](#permissions).id (cascade) |

### roles

Duy nhất: (company_id, name_key)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id (cascade) |
| `name` | varchar(100) |  | ∅ |  |
| `description` | varchar(200) | có | ∅ |  |
| `is_default` | tinyint(1) |  | 0 |  |
| `is_system` | tinyint(1) |  | 0 |  |
| `role_view_all_company` | tinyint(1) |  | 1 |  |
| `role_view_department_id` | bigint | có | ∅ | ↗ [departments](#departments).id (set null) |
| `deleted` | tinyint(1) |  | 0 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `name_key` | varchar(100) | có | ∅ |  |

### system_admins

Duy nhất: (email)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `email` | varchar(100) |  | ∅ |  |
| `password` | varchar(255) |  | ∅ |  |
| `name` | varchar(100) |  | ∅ |  |
| `enabled` | tinyint(1) |  | 1 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `totp_secret` | varchar(64) | có | ∅ |  |
| `totp_enabled` | tinyint(1) |  | 0 |  |
| `totp_recovery_codes` | text | có | ∅ |  |

### trial_requests

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `full_name` | varchar(100) |  | ∅ |  |
| `company_name` | varchar(150) |  | ∅ |  |
| `phone` | varchar(30) |  | ∅ |  |
| `email` | varchar(150) | có | ∅ |  |
| `company_size` | varchar(30) | có | ∅ |  |
| `need` | varchar(1000) | có | ∅ |  |
| `status` | enum('NEW','CONTACTED','TRIAL','REJECTED') |  | NEW |  |
| `admin_note` | varchar(1000) | có | ∅ |  |
| `source` | varchar(200) | có | ∅ |  |
| `ip` | varchar(64) | có | ∅ |  |
| `handled_by` | varchar(150) | có | ∅ |  |
| `handled_at` | datetime(6) | có | ∅ |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |

### user_permission_dept_scopes

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `user_id` | bigint |  | ∅ | 🔑 ↗ [users](#users).id (cascade) |
| `permission_code` | varchar(50) |  | ∅ | 🔑 |
| `department_id` | bigint |  | ∅ | 🔑 |

### user_permissions

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `user_id` | bigint |  | ∅ | 🔑 ↗ [users](#users).id (cascade) |
| `permission_id` | bigint |  | ∅ | 🔑 ↗ [permissions](#permissions).id (cascade) |

### user_roles

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `user_id` | bigint |  | ∅ | 🔑 ↗ [users](#users).id (cascade) |
| `role_id` | bigint |  | ∅ | 🔑 ↗ [roles](#roles).id (cascade) |

### user_sessions

Duy nhất: (jti)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `user_id` | bigint |  | ∅ | ↗ [users](#users).id (cascade) |
| `jti` | varchar(36) |  | ∅ | JWT ID of the refresh token |
| `device_id` | varchar(255) |  | ∅ |  |
| `expires_at` | datetime |  | ∅ |  |
| `revoked` | tinyint(1) |  | 0 |  |
| `created_at` | datetime |  | CURRENT_TIMESTAMP |  |
| `updated_at` | datetime |  | CURRENT_TIMESTAMP |  |

### users

Duy nhất: (employee_id) · (email_key)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id (cascade) |
| `email` | varchar(100) |  | ∅ |  |
| `password` | varchar(255) |  | ∅ |  |
| `employee_id` | bigint | có | ∅ | ↗ [employees](#employees).id (set null) |
| `enabled` | tinyint(1) |  | 1 |  |
| `deleted` | tinyint(1) |  | 0 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `fcm_token` | varchar(512) | có | ∅ |  |
| `shift_reminder_minutes` | int | có | ∅ |  |
| `check_in_out_notif_minutes` | int | có | ∅ | Sá»‘ phÃºt trÆ°á»›c ca (check-in) / sau ca (check-out) Ä‘á»ƒ gá»­i thÃ´ng bÃ¡o. NULL = táº¯t |
| `email_key` | varchar(100) | có | ∅ |  |
| `must_change_password` | tinyint(1) |  | 0 |  |
| `totp_secret` | varchar(64) | có | ∅ |  |
| `totp_enabled` | tinyint(1) |  | 0 |  |
| `totp_recovery_codes` | text | có | ∅ |  |
| `language` | varchar(5) | có | ∅ |  |

## Tổ chức & nhân viên

### departments

Duy nhất: (company_id, code_key)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id (cascade) |
| `name` | varchar(100) |  | ∅ |  |
| `code` | varchar(20) |  | ∅ |  |
| `description` | text | có | ∅ |  |
| `manager_id` | bigint | có | ∅ | ↗ [employees](#employees).id (set null) |
| `parent_id` | bigint | có | ∅ | ↗ [departments](#departments).id (set null) |
| `level` | int |  | 0 |  |
| `deleted` | tinyint(1) |  | 0 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `check_in_latitude` | double | có | ∅ |  |
| `check_in_longitude` | double | có | ∅ |  |
| `check_in_radius_meters` | int |  | 100 |  |
| `check_in_tolerance_minutes` | int | có | ∅ |  |
| `check_out_tolerance_minutes` | int | có | ∅ |  |
| `rounding_check_in_minutes` | int | có | ∅ |  |
| `rounding_check_out_minutes` | int | có | ∅ |  |
| `rounding_work_minutes` | int | có | ∅ |  |
| `code_key` | varchar(20) | có | ∅ |  |
| `work_calendar_id` | bigint | có | ∅ | ↗ [work_calendars](#work_calendars).id (set null) |

### document_types

Duy nhất: (company_id, code_key)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id |
| `code` | varchar(30) |  | ∅ |  |
| `name` | varchar(150) |  | ∅ |  |
| `required` | tinyint(1) |  | 0 |  |
| `has_expiry` | tinyint(1) |  | 0 |  |
| `sort_order` | int |  | 0 |  |
| `deleted` | tinyint(1) |  | 0 |  |
| `code_key` | varchar(30) | có | ∅ |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |

### employee_code_counters

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `company_id` | bigint |  | ∅ | 🔑 ↗ [companies](#companies).id |
| `last_seq` | int |  | ∅ |  |

### employee_dependents

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ |  |
| `employee_id` | bigint |  | ∅ | ↗ [employees](#employees).id |
| `full_name` | varchar(100) |  | ∅ |  |
| `relationship` | enum('CHILD','SPOUSE','PARENT','OTHER') |  | ∅ |  |
| `date_of_birth` | date | có | ∅ |  |
| `tax_code` | varchar(20) | có | ∅ |  |
| `identity_no` | varchar(20) | có | ∅ |  |
| `deduction_from` | date |  | ∅ |  |
| `deduction_to` | date | có | ∅ |  |
| `registration_status` | enum('NOT_REGISTERED','PENDING','REGISTERED') |  | PENDING |  |
| `note` | varchar(500) | có | ∅ |  |
| `deleted` | tinyint(1) |  | 0 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |

### employee_documents

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ |  |
| `employee_id` | bigint |  | ∅ | ↗ [employees](#employees).id |
| `document_type_id` | bigint |  | ∅ | ↗ [document_types](#document_types).id |
| `title` | varchar(200) | có | ∅ |  |
| `file_key` | varchar(300) |  | ∅ |  |
| `file_name` | varchar(255) |  | ∅ |  |
| `content_type` | varchar(100) |  | ∅ |  |
| `file_size` | bigint |  | ∅ |  |
| `issued_on` | date | có | ∅ |  |
| `expires_on` | date | có | ∅ |  |
| `contract_id` | bigint | có | ∅ | ↗ [labor_contracts](#labor_contracts).id (set null) |
| `status` | enum('PENDING','APPROVED','REJECTED') |  | APPROVED |  |
| `review_note` | varchar(500) | có | ∅ |  |
| `reviewed_by` | bigint | có | ∅ |  |
| `reviewed_at` | datetime(6) | có | ∅ |  |
| `note` | varchar(500) | có | ∅ |  |
| `uploaded_by` | bigint | có | ∅ |  |
| `deleted` | tinyint(1) |  | 0 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |

### employee_job_histories

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id (cascade) |
| `employee_id` | bigint |  | ∅ | ↗ [employees](#employees).id (cascade) |
| `effective_from` | date |  | ∅ |  |
| `change_type` | enum('HIRE','TRANSFER','PROMOTION','SALARY_CHANGE','MANAGER_CHANGE','OTHER') |  | OTHER |  |
| `department_id` | bigint |  | ∅ | ↗ [departments](#departments).id |
| `position_id` | bigint | có | ∅ | ↗ [positions](#positions).id (set null) |
| `salary_grade_id` | bigint | có | ∅ | ↗ [salary_grades](#salary_grades).id (set null) |
| `manager_id` | bigint | có | ∅ | ↗ [employees](#employees).id (set null) |
| `note` | varchar(500) | có | ∅ |  |
| `applied` | tinyint(1) |  | 0 |  |
| `created_by` | bigint | có | ∅ | ↗ [users](#users).id (set null) |
| `deleted` | tinyint(1) |  | 0 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |

### employee_locations

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `employee_id` | bigint |  | ∅ | ↗ [employees](#employees).id (cascade) |
| `name` | varchar(100) |  | ∅ |  |
| `latitude` | double |  | ∅ |  |
| `longitude` | double |  | ∅ |  |
| `radius_meters` | int |  | 100 |  |

### employees

Duy nhất: (company_id, code_key) · (company_id, email_key)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id (cascade) |
| `employee_code` | varchar(20) |  | ∅ |  |
| `full_name` | varchar(100) |  | ∅ |  |
| `email` | varchar(100) |  | ∅ |  |
| `phone` | varchar(15) | có | ∅ |  |
| `personal_email` | varchar(100) | có | ∅ |  |
| `avatar` | varchar(255) | có | ∅ |  |
| `gender` | enum('MALE','FEMALE','OTHER') |  | ∅ |  |
| `date_of_birth` | date | có | ∅ |  |
| `join_date` | date |  | ∅ |  |
| `leave_date` | date | có | ∅ |  |
| `status` | enum('ACTIVE','INACTIVE','ON_LEAVE') |  | ACTIVE |  |
| `department_id` | bigint |  | ∅ | ↗ [departments](#departments).id |
| `position_id` | bigint | có | ∅ | ↗ [positions](#positions).id |
| `address` | text | có | ∅ |  |
| `identity_card` | varchar(20) | có | ∅ |  |
| `bank_account` | varchar(30) | có | ∅ |  |
| `bank_name` | varchar(100) | có | ∅ |  |
| `deleted` | tinyint(1) |  | 0 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `salary_grade_id` | bigint | có | ∅ | ↗ [salary_grades](#salary_grades).id |
| `contract_salary` | decimal(15,2) | có | ∅ | LÆ°Æ¡ng cÆ¡ báº£n theo há»£p Ä‘á»“ng |
| `code_key` | varchar(20) | có | ∅ |  |
| `email_key` | varchar(100) | có | ∅ |  |
| `bound_device_id` | varchar(255) | có | ∅ |  |
| `bound_device_at` | datetime(6) | có | ∅ |  |
| `manager_id` | bigint | có | ∅ | ↗ [employees](#employees).id (set null) |
| `tax_code` | varchar(20) | có | ∅ |  |
| `social_insurance_no` | varchar(20) | có | ∅ |  |
| `health_insurance_place` | varchar(255) | có | ∅ |  |
| `insurance_join_date` | date | có | ∅ |  |

### positions

Duy nhất: (company_id, code_key)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `name` | varchar(100) |  | ∅ |  |
| `code` | varchar(20) |  | ∅ |  |
| `department_id` | bigint | có | ∅ | ↗ [departments](#departments).id |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id |
| `description` | text | có | ∅ |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `deleted` | tinyint(1) |  | 0 |  |
| `code_key` | varchar(20) | có | ∅ |  |

### profile_edit_requests

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `employee_id` | bigint |  | ∅ | ↗ [employees](#employees).id (cascade) |
| `full_name` | varchar(100) | có | ∅ |  |
| `gender` | enum('MALE','FEMALE','OTHER') | có | ∅ |  |
| `date_of_birth` | date | có | ∅ |  |
| `phone` | varchar(15) | có | ∅ |  |
| `personal_email` | varchar(100) | có | ∅ |  |
| `avatar_url` | varchar(255) | có | ∅ |  |
| `status` | enum('PENDING','APPROVED','REJECTED','CANCELLED') |  | PENDING |  |
| `admin_note` | text | có | ∅ |  |
| `processed_by` | bigint | có | ∅ | ↗ [users](#users).id (set null) |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `old_full_name` | varchar(100) | có | ∅ |  |
| `old_gender` | enum('MALE','FEMALE','OTHER') | có | ∅ |  |
| `old_date_of_birth` | date | có | ∅ |  |
| `old_phone` | varchar(15) | có | ∅ |  |
| `old_personal_email` | varchar(100) | có | ∅ |  |
| `processed_at` | datetime(6) | có | ∅ |  |

## Hợp đồng

### contract_allowances

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `contract_id` | bigint |  | ∅ | ↗ [labor_contracts](#labor_contracts).id (cascade) |
| `appendix_id` | bigint | có | ∅ | ↗ [contract_appendices](#contract_appendices).id (cascade) |
| `code` | varchar(30) |  | ∅ |  |
| `name` | varchar(150) |  | ∅ |  |
| `amount` | decimal(15,2) |  | ∅ |  |
| `insurable` | tinyint(1) |  | 0 |  |
| `taxable` | tinyint(1) |  | 1 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |

### contract_appendices

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `contract_id` | bigint |  | ∅ | ↗ [labor_contracts](#labor_contracts).id (cascade) |
| `appendix_no` | varchar(50) |  | ∅ |  |
| `effective_from` | date |  | ∅ |  |
| `base_salary` | decimal(15,2) | có | ∅ |  |
| `insurance_salary` | decimal(15,2) | có | ∅ |  |
| `position_title` | varchar(150) | có | ∅ |  |
| `overrides_allowances` | tinyint(1) |  | 0 |  |
| `note` | varchar(1000) | có | ∅ |  |
| `deleted` | tinyint(1) |  | 0 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |

### labor_contracts

Duy nhất: (company_id, contract_no_key)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id (cascade) |
| `employee_id` | bigint |  | ∅ | ↗ [employees](#employees).id (cascade) |
| `contract_no` | varchar(50) |  | ∅ |  |
| `contract_type` | enum('PROBATION','FIXED_TERM','INDEFINITE','SEASONAL','SERVICE') |  | ∅ |  |
| `status` | enum('DRAFT','ACTIVE','TERMINATED') |  | DRAFT |  |
| `sign_date` | date | có | ∅ |  |
| `start_date` | date |  | ∅ |  |
| `end_date` | date | có | ∅ |  |
| `base_salary` | decimal(15,2) |  | ∅ |  |
| `insurance_salary` | decimal(15,2) | có | ∅ |  |
| `position_title` | varchar(150) | có | ∅ |  |
| `note` | varchar(1000) | có | ∅ |  |
| `termination_date` | date | có | ∅ |  |
| `termination_reason` | varchar(500) | có | ∅ |  |
| `created_by` | bigint | có | ∅ | ↗ [users](#users).id (set null) |
| `deleted` | tinyint(1) |  | 0 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `contract_no_key` | varchar(50) | có | ∅ |  |

## Ca làm

### shift_assignments

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `employee_id` | bigint |  | ∅ | ↗ [employees](#employees).id (cascade) |
| `shift_id` | bigint | có | ∅ | ↗ [work_shifts](#work_shifts).id |
| `work_date` | date |  | ∅ |  |
| `note` | varchar(255) | có | ∅ |  |
| `custom_start_time` | time | có | ∅ |  |
| `custom_end_time` | time | có | ∅ |  |
| `custom_break_start` | time | có | ∅ |  |
| `custom_break_end` | time | có | ∅ |  |
| `created_by` | bigint | có | ∅ |  |
| `created_at` | datetime |  | CURRENT_TIMESTAMP |  |
| `deleted` | tinyint(1) |  | 0 |  |
| `approved` | tinyint(1) |  | 0 |  |
| `snapshot_name` | varchar(100) | có | ∅ |  |
| `snapshot_code` | varchar(20) | có | ∅ |  |
| `snapshot_start_time` | time | có | ∅ |  |
| `snapshot_end_time` | time | có | ∅ |  |
| `snapshot_break_start` | time | có | ∅ |  |
| `snapshot_break_end` | time | có | ∅ |  |
| `snapshot_work_minutes` | int | có | ∅ |  |
| `snapshot_color` | varchar(7) | có | ∅ |  |
| `reminder_sent_at` | datetime | có | ∅ |  |
| `check_in_notif_sent_at` | datetime | có | ∅ |  |
| `check_out_notif_sent_at` | datetime | có | ∅ |  |
| `snapshot_shift_type` | varchar(20) | có | ∅ |  |
| `snapshot_required_minutes` | int | có | ∅ |  |

### shift_registration_round_departments

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `round_id` | bigint |  | ∅ | 🔑 ↗ [shift_registration_rounds](#shift_registration_rounds).id (cascade) |
| `department_id` | bigint |  | ∅ | 🔑 ↗ [departments](#departments).id (cascade) |

### shift_registration_rounds

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id (cascade) |
| `name` | varchar(100) |  | ∅ |  |
| `from_date` | date |  | ∅ |  |
| `to_date` | date |  | ∅ |  |
| `status` | enum('DRAFT','OPEN','CLOSED') |  | DRAFT |  |
| `closes_at` | datetime(6) | có | ∅ |  |
| `earliest_time` | time | có | ∅ |  |
| `latest_time` | time | có | ∅ |  |
| `min_hours` | decimal(4,2) | có | ∅ |  |
| `max_hours` | decimal(4,2) | có | ∅ |  |
| `min_days` | int | có | ∅ |  |
| `needed_per_day` | int | có | ∅ |  |
| `note` | varchar(500) | có | ∅ |  |
| `created_by` | bigint | có | ∅ | ↗ [users](#users).id (set null) |
| `deleted` | tinyint(1) |  | 0 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |

### shift_registrations

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `round_id` | bigint |  | ∅ | ↗ [shift_registration_rounds](#shift_registration_rounds).id (cascade) |
| `employee_id` | bigint |  | ∅ | ↗ [employees](#employees).id (cascade) |
| `work_date` | date |  | ∅ |  |
| `kind` | enum('SHIFT','CUSTOM','ANY') |  | ∅ |  |
| `shift_id` | bigint | có | ∅ | ↗ [work_shifts](#work_shifts).id (set null) |
| `start_time` | time | có | ∅ |  |
| `end_time` | time | có | ∅ |  |
| `note` | varchar(255) | có | ∅ |  |
| `status` | enum('PENDING','APPROVED','REJECTED') |  | PENDING |  |
| `assignment_id` | bigint | có | ∅ | ↗ [shift_assignments](#shift_assignments).id (set null) |
| `decided_by` | bigint | có | ∅ | ↗ [users](#users).id (set null) |
| `decided_at` | datetime(6) | có | ∅ |  |
| `deleted` | tinyint(1) |  | 0 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |

### shift_rotations

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id |
| `name` | varchar(100) |  | ∅ |  |
| `pattern` | varchar(2000) |  | ∅ |  |
| `active` | tinyint(1) |  | 1 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |

### shift_swap_requests

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id |
| `requester_id` | bigint |  | ∅ | ↗ [employees](#employees).id |
| `requester_assignment_id` | bigint |  | ∅ | ↗ [shift_assignments](#shift_assignments).id |
| `target_employee_id` | bigint |  | ∅ | ↗ [employees](#employees).id |
| `target_assignment_id` | bigint | có | ∅ | ↗ [shift_assignments](#shift_assignments).id |
| `reason` | varchar(500) | có | ∅ |  |
| `status` | varchar(20) |  | PENDING |  |
| `processed_by_id` | bigint | có | ∅ | ↗ [users](#users).id (set null) |
| `processed_at` | datetime(6) | có | ∅ |  |
| `admin_note` | varchar(500) | có | ∅ |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `manager_approved_by` | bigint | có | ∅ | ↗ [users](#users).id (set null) |
| `manager_approved_at` | datetime(6) | có | ∅ |  |
| `manager_note` | varchar(500) | có | ∅ |  |

### work_shifts

Duy nhất: (company_id, code_key)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id (cascade) |
| `name` | varchar(100) |  | ∅ |  |
| `code` | varchar(20) |  | ∅ |  |
| `start_time` | time | có | ∅ |  |
| `end_time` | time | có | ∅ |  |
| `break_start` | time | có | ∅ |  |
| `break_end` | time | có | ∅ |  |
| `work_minutes` | int | có | ∅ |  |
| `color` | varchar(7) |  | #1976D2 |  |
| `active` | tinyint(1) |  | 1 |  |
| `created_at` | datetime |  | CURRENT_TIMESTAMP |  |
| `updated_at` | datetime |  | CURRENT_TIMESTAMP |  |
| `group_name` | varchar(100) | có | ∅ |  |
| `code_key` | varchar(20) | có | ∅ |  |
| `shift_type` | varchar(20) |  | FIXED |  |
| `required_minutes` | int | có | ∅ |  |

## Chấm công

### attendance_approve_leaves

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `attendance_id` | bigint |  | ∅ | ↗ [attendances](#attendances).id (cascade) |
| `leave_request_id` | bigint |  | ∅ | ↗ [leave_requests](#leave_requests).id (cascade) |
| `leave_type_name` | varchar(100) |  | ∅ |  |
| `paid` | tinyint(1) |  | 0 |  |
| `leave_hours` | double |  | 0 |  |

### attendance_period_locks

Duy nhất: (company_id, year, month)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id |
| `year` | int |  | ∅ |  |
| `month` | int |  | ∅ |  |
| `period_from` | date |  | ∅ |  |
| `period_to` | date |  | ∅ |  |
| `locked` | tinyint(1) |  | 1 |  |
| `locked_at` | datetime(6) | có | ∅ |  |
| `locked_by_id` | bigint | có | ∅ | ↗ [users](#users).id (set null) |
| `unlocked_at` | datetime(6) | có | ∅ |  |
| `unlocked_by_id` | bigint | có | ∅ | ↗ [users](#users).id (set null) |
| `unlock_reason` | varchar(500) | có | ∅ |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |

### attendance_requests

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `employee_id` | bigint |  | ∅ | ↗ [employees](#employees).id (cascade) |
| `shift_assignment_id` | bigint | có | ∅ | ↗ [shift_assignments](#shift_assignments).id (set null) |
| `request_date` | date |  | ∅ |  |
| `request_type` | varchar(20) |  | ∅ |  |
| `requested_check_in` | time | có | ∅ |  |
| `requested_check_out` | time | có | ∅ |  |
| `requested_overtime_minutes` | int | có | ∅ |  |
| `requested_overtime_scope` | varchar(20) | có | ∅ |  |
| `requested_overtime_period` | varchar(20) | có | ∅ |  |
| `applied` | tinyint(1) |  | 1 |  |
| `note` | text | có | ∅ |  |
| `status` | varchar(20) |  | PENDING |  |
| `admin_note` | text | có | ∅ |  |
| `processed_by` | bigint | có | ∅ | ↗ [users](#users).id (set null) |
| `processed_at` | datetime(6) | có | ∅ |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `active_key` | tinyint | có | ∅ |  |
| `manager_approved_by` | bigint | có | ∅ | ↗ [users](#users).id (set null) |
| `manager_approved_at` | datetime(6) | có | ∅ |  |
| `manager_note` | varchar(500) | có | ∅ |  |

### attendances

Duy nhất: (employee_id, date, slot_key)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `employee_id` | bigint |  | ∅ | ↗ [employees](#employees).id |
| `shift_assignment_id` | bigint | có | ∅ | ↗ [shift_assignments](#shift_assignments).id (set null) |
| `date` | date |  | ∅ |  |
| `check_in` | datetime(6) | có | ∅ |  |
| `check_out` | datetime(6) | có | ∅ |  |
| `status` | enum('PRESENT','ABSENT','LATE','HALF_DAY','LEAVE') | có | ∅ |  |
| `note` | text | có | ∅ |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `approved` | tinyint(1) |  | 0 |  |
| `approved_at` | datetime | có | ∅ |  |
| `approved_by_id` | bigint | có | ∅ | ↗ [users](#users).id |
| `snap_actual_hours` | double | có | ∅ |  |
| `snap_day_hours` | double | có | ∅ |  |
| `snap_day_ot` | double | có | ∅ |  |
| `snap_night_hours` | double | có | ∅ |  |
| `snap_night_ot` | double | có | ∅ |  |
| `check_in_latitude` | double | có | ∅ |  |
| `check_in_longitude` | double | có | ∅ |  |
| `check_out_latitude` | double | có | ∅ |  |
| `check_out_longitude` | double | có | ∅ |  |
| `work_flags` | varchar(120) | có | ∅ | Comma-separated flags: EARLY_IN,LATE_IN,EARLY_OUT,LATE_OUT,ON_TIME,OVERTIME,LEAVE |
| `override_break_minutes` | int | có | ∅ |  |
| `override_ot_day_minutes` | int | có | ∅ |  |
| `override_ot_night_minutes` | int | có | ∅ |  |
| `override_note` | varchar(255) | có | ∅ |  |
| `deleted` | tinyint(1) |  | 0 |  |
| `deleted_at` | datetime | có | ∅ |  |
| `deleted_by_id` | bigint | có | ∅ | ↗ [users](#users).id |
| `override_check_in` | datetime(6) | có | ∅ |  |
| `override_check_out` | datetime(6) | có | ∅ |  |
| `punch_no` | int |  | 0 |  |
| `slot_key` | bigint | có | ∅ |  |

## Nghỉ phép

### leave_accrual_rules

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id |
| `department_id` | bigint | có | ∅ | ↗ [departments](#departments).id |
| `name` | varchar(100) |  | ∅ |  |
| `frequency` | enum('MONTHLY','YEARLY') |  | ∅ |  |
| `day_of_month` | int | có | ∅ |  |
| `month_of_year` | int | có | ∅ |  |
| `min_tenure_years` | int |  | 0 |  |
| `valid_from` | date | có | ∅ |  |
| `valid_to` | date | có | ∅ |  |
| `expire_after_days` | int | có | ∅ |  |
| `active` | tinyint(1) |  | 1 |  |
| `deleted` | tinyint(1) |  | 0 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `grant_days` | decimal(10,2) | có | ∅ |  |
| `grant_hours` | decimal(10,2) | có | ∅ |  |

### leave_grants

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id |
| `employee_id` | bigint |  | ∅ | ↗ [employees](#employees).id |
| `leave_type_id` | bigint | có | ∅ | ↗ [leave_types](#leave_types).id |
| `source` | enum('MANUAL','AUTO') |  | ∅ |  |
| `granted_at` | date |  | ∅ |  |
| `valid_from` | date | có | ∅ |  |
| `valid_to` | date | có | ∅ |  |
| `note` | varchar(500) | có | ∅ |  |
| `accrual_rule_id` | bigint | có | ∅ | ↗ [leave_accrual_rules](#leave_accrual_rules).id |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `grant_days` | decimal(10,2) | có | ∅ |  |
| `grant_hours` | decimal(10,2) | có | ∅ |  |
| `used_days` | decimal(10,2) |  | 0.00 |  |
| `used_hours` | decimal(10,2) |  | 0.00 |  |
| `version` | bigint |  | 0 |  |

### leave_ledger_entries

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id |
| `employee_id` | bigint |  | ∅ | ↗ [employees](#employees).id |
| `grant_id` | bigint |  | ∅ | ↗ [leave_grants](#leave_grants).id |
| `request_id` | bigint |  | ∅ | ↗ [leave_requests](#leave_requests).id |
| `kind` | enum('DEDUCT','REFUND') |  | ∅ |  |
| `days` | decimal(10,4) |  | 0.0000 |  |
| `hours` | decimal(10,4) |  | 0.0000 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |

### leave_requests

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `employee_id` | bigint |  | ∅ | ↗ [employees](#employees).id |
| `reason` | varchar(500) | có | ∅ |  |
| `status` | enum('PENDING','APPROVED','REJECTED','CANCELLED') |  | PENDING |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id |
| `leave_type_id` | bigint |  | ∅ | ↗ [leave_types](#leave_types).id |
| `mode` | enum('DAY_RANGE','HOUR_RANGE') |  | ∅ |  |
| `from_date` | date |  | ∅ |  |
| `to_date` | date |  | ∅ |  |
| `from_time` | time | có | ∅ |  |
| `to_time` | time | có | ∅ |  |
| `requested_amount` | decimal(10,2) |  | ∅ |  |
| `admin_note` | varchar(500) | có | ∅ |  |
| `processed_by` | bigint | có | ∅ | ↗ [users](#users).id |
| `processed_at` | datetime(6) | có | ∅ |  |
| `applied` | tinyint(1) |  | 1 |  |
| `parent_id` | bigint | có | ∅ | ↗ [leave_requests](#leave_requests).id (cascade) |
| `manager_approved_by` | bigint | có | ∅ | ↗ [users](#users).id (set null) |
| `manager_approved_at` | datetime(6) | có | ∅ |  |
| `manager_note` | varchar(500) | có | ∅ |  |

### leave_types

Duy nhất: (company_id, code_key)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id |
| `code` | varchar(50) |  | ∅ |  |
| `name` | varchar(100) |  | ∅ |  |
| `unit` | enum('DAY','HOUR') |  | ∅ |  |
| `deduct_per_day` | decimal(10,2) |  | 1.00 |  |
| `is_paid` | tinyint(1) |  | 1 |  |
| `requires_balance` | tinyint(1) |  | 1 |  |
| `active` | tinyint(1) |  | 1 |  |
| `deleted` | tinyint(1) |  | 0 |  |
| `description` | varchar(255) | có | ∅ |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `code_key` | varchar(50) | có | ∅ |  |

## Lịch & ngày lễ

### holidays

Duy nhất: (company_key, date_key)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint | có | ∅ | ↗ [companies](#companies).id (cascade) |
| `holiday_date` | date |  | ∅ |  |
| `name` | varchar(150) |  | ∅ |  |
| `type` | enum('HOLIDAY','COMPENSATORY','SWAP_WORKDAY') |  | HOLIDAY |  |
| `paid` | tinyint(1) |  | 1 |  |
| `deleted` | tinyint(1) |  | 0 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `date_key` | date | có | ∅ |  |
| `company_key` | bigint | có | ∅ |  |

### work_calendars

Duy nhất: (company_id, default_key)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id (cascade) |
| `name` | varchar(100) |  | ∅ |  |
| `week_pattern` | varchar(7) |  | FFFFFOO |  |
| `is_default` | tinyint(1) |  | 0 |  |
| `deleted` | tinyint(1) |  | 0 |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `default_key` | tinyint | có | ∅ |  |

## Lương & thuế

### formula_variables

Duy nhất: (company_id, name)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ | ↗ [companies](#companies).id |
| `name` | varchar(50) |  | ∅ |  |
| `label` | varchar(100) |  | ∅ |  |
| `expression` | text |  | ∅ |  |
| `created_at` | datetime |  | CURRENT_TIMESTAMP |  |
| `updated_at` | datetime |  | CURRENT_TIMESTAMP |  |
| `show_in_formula` | tinyint(1) |  | 1 |  |
| `category` | varchar(50) | có | ∅ |  |

### payrolls

Duy nhất: (employee_id, year, month)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `employee_id` | bigint |  | ∅ | ↗ [employees](#employees).id |
| `year` | int |  | ∅ |  |
| `month` | int |  | ∅ |  |
| `base_salary` | decimal(15,2) |  | ∅ |  |
| `allowance` | decimal(15,2) |  | 0.00 |  |
| `bonus` | decimal(15,2) |  | 0.00 |  |
| `overtime_pay` | decimal(15,2) |  | 0.00 |  |
| `gross_salary` | decimal(15,2) |  | ∅ |  |
| `social_insurance` | decimal(15,2) |  | ∅ |  |
| `health_insurance` | decimal(15,2) |  | ∅ |  |
| `unemployment_insurance` | decimal(15,2) |  | ∅ |  |
| `personal_income_tax` | decimal(15,2) |  | ∅ |  |
| `other_deductions` | decimal(15,2) |  | 0.00 |  |
| `net_salary` | decimal(15,2) |  | ∅ |  |
| `status` | enum('DRAFT','APPROVED','PAID') |  | DRAFT |  |
| `note` | text | có | ∅ |  |
| `paid_at` | datetime(6) | có | ∅ |  |
| `approved_at` | datetime(6) | có | ∅ |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |
| `present_days` | int | có | ∅ |  |
| `total_overtime_hours` | decimal(8,2) | có | ∅ |  |
| `custom_deductions` | json | có | ∅ |  |
| `day_hours` | decimal(8,2) | có | ∅ |  |
| `night_hours` | decimal(8,2) | có | ∅ |  |
| `day_ot` | decimal(8,2) | có | ∅ |  |
| `night_ot` | decimal(8,2) | có | ∅ |  |
| `pay_type` | varchar(10) | có | ∅ |  |
| `standard_work_days` | decimal(5,2) | có | ∅ |  |
| `period_from` | date | có | ∅ |  |
| `period_to` | date | có | ∅ |  |
| `income_entries` | json | có | ∅ | Thu nháº­p thÃªm snapshot: {"VAR": {label, amount}} |
| `allowance_entries` | json | có | ∅ | Trá»£ cáº¥p snapshot: {"VAR": {label, amount}} |
| `custom_formula` | json | có | ∅ | Inline formula snapshot, chá»‰ Ã¡p dá»¥ng cho payroll nÃ y |
| `salary_grade_id` | bigint | có | ∅ | ↗ [salary_grades](#salary_grades).id (set null) |
| `salary_grade_code` | varchar(50) | có | ∅ |  |
| `salary_grade_name` | varchar(255) | có | ∅ |  |
| `approved_by_id` | bigint | có | ∅ | ↗ [users](#users).id (set null) |
| `paid_by_id` | bigint | có | ∅ | ↗ [users](#users).id (set null) |
| `family_deduction` | decimal(15,2) | có | ∅ |  |
| `insurance_base` | decimal(15,2) | có | ∅ |  |
| `department_id` | bigint | có | ∅ |  |
| `department_name` | varchar(255) | có | ∅ |  |
| `dependents` | int | có | ∅ |  |
| `employer_social_ins` | decimal(15,2) | có | ∅ |  |
| `employer_health_ins` | decimal(15,2) | có | ∅ |  |
| `employer_unemployment_ins` | decimal(15,2) | có | ∅ |  |

### salary_formulas

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `effective_date` | date |  | ∅ |  |
| `expression_gross` | text |  | ∅ |  |
| `expression_net` | text |  | ∅ |  |
| `created_at` | datetime |  | CURRENT_TIMESTAMP |  |
| `updated_at` | datetime |  | CURRENT_TIMESTAMP |  |
| `salary_grade_id` | bigint |  | ∅ | ↗ [salary_grades](#salary_grades).id |
| `name` | varchar(100) |  | ∅ |  |
| `custom_vars` | json | có | ∅ | Private variables: {"VAR_NAME": "expression", ...} |
| `deduction_vars` | json | có | ∅ |  |
| `income_vars` | json | có | ∅ | Thu nháº­p thÃªm: {"VAR": {label, expression}} |
| `allowance_vars` | json | có | ∅ | Trá»£ cáº¥p: {"VAR": {label, expression}} |

### salary_grades

Duy nhất: (company_id, grade_key)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `code` | varchar(20) |  | ∅ |  |
| `name` | varchar(100) |  | ∅ |  |
| `pay_type` | enum('DAILY','HOURLY') |  | DAILY |  |
| `base_rate` | decimal(15,2) |  | ∅ |  |
| `created_at` | datetime |  | CURRENT_TIMESTAMP |  |
| `updated_at` | datetime |  | CURRENT_TIMESTAMP |  |
| `department_id` | bigint | có | ∅ | ↗ [departments](#departments).id |
| `company_id` | bigint | có | ∅ | ↗ [companies](#companies).id |
| `deleted` | tinyint(1) |  | 0 |  |
| `grade_key` | varchar(80) | có | ∅ |  |

### salary_histories

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `employee_id` | bigint |  | ∅ | ↗ [employees](#employees).id |
| `base_salary` | decimal(15,2) |  | ∅ |  |
| `effective_date` | date |  | ∅ |  |
| `note` | text | có | ∅ |  |
| `created_at` | datetime |  | CURRENT_TIMESTAMP |  |
| `updated_at` | datetime |  | CURRENT_TIMESTAMP |  |

### tax_policies

Duy nhất: (effective_from)

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `effective_from` | date |  | ∅ |  |
| `personal_deduction` | decimal(15,2) |  | ∅ | Giảm trừ bản thân / tháng |
| `dependent_deduction` | decimal(15,2) |  | ∅ | Giảm trừ mỗi người phụ thuộc / tháng |
| `pit_brackets` | varchar(1000) |  | ∅ | JSON [{"upTo":10000000,"rate":0.05},...,{"upTo":null,"rate":0.35}] theo tháng |
| `reference_wage` | decimal(15,2) |  | ∅ | Mức tham chiếu (= lương cơ sở) — trần BHXH/BHYT |
| `insurance_cap_multiplier` | int |  | 20 |  |
| `unemployment_cap_multiplier` | int |  | 20 |  |
| `min_wage_region1` | decimal(15,2) |  | ∅ |  |
| `min_wage_region2` | decimal(15,2) |  | ∅ |  |
| `min_wage_region3` | decimal(15,2) |  | ∅ |  |
| `min_wage_region4` | decimal(15,2) |  | ∅ |  |
| `note` | varchar(500) | có | ∅ |  |
| `updated_by` | varchar(150) | có | ∅ |  |
| `created_at` | datetime(6) |  | ∅ |  |
| `updated_at` | datetime(6) |  | ∅ |  |

## Nhật ký, Excel, khác

### audit_logs

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint | có | ∅ |  |
| `actor_user_id` | bigint | có | ∅ |  |
| `actor_email` | varchar(150) | có | ∅ |  |
| `actor_type` | enum('USER','SYSTEM_ADMIN','IMPERSONATE','SYSTEM') |  | ∅ |  |
| `action` | varchar(50) |  | ∅ |  |
| `entity_type` | varchar(50) | có | ∅ |  |
| `entity_id` | varchar(64) | có | ∅ |  |
| `summary` | varchar(500) | có | ∅ |  |
| `detail` | text | có | ∅ |  |
| `ip` | varchar(64) | có | ∅ |  |
| `request_id` | varchar(64) | có | ∅ |  |
| `created_at` | datetime(6) |  | ∅ |  |

### department_shifts

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `department_id` | bigint |  | ∅ | 🔑 ↗ [departments](#departments).id (cascade) |
| `shift_id` | bigint |  | ∅ | 🔑 ↗ [work_shifts](#work_shifts).id (cascade) |

### excel_history

| Cột | Kiểu | Null | Mặc định | Ghi chú |
|---|---|---|---|---|
| `id` | bigint |  | ∅ | 🔑 tự tăng |
| `company_id` | bigint |  | ∅ |  |
| `user_id` | bigint | có | ∅ |  |
| `type` | enum('EXPORT','IMPORT','REPORT') |  | ∅ |  |
| `module` | varchar(255) |  | ∅ |  |
| `filename` | varchar(255) |  | ∅ |  |
| `file_url` | varchar(1024) | có | ∅ |  |
| `ok_count` | int | có | ∅ |  |
| `error_count` | int | có | ∅ |  |
| `skip_count` | int | có | ∅ |  |
| `created_at` | datetime(6) |  | CURRENT_TIMESTAMP(6) |  |
