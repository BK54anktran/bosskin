-- =====================================================================
-- V1 · Baseline schema BossKin (gộp V1–V117 trước go-live, 10/2026)
--
-- Sinh từ schema sau khi chạy đủ 117 migration cũ, rồi:
--   * bỏ toàn bộ dữ liệu demo (công ty mẫu, tài khoản admin/sysadmin có mật khẩu
--     công khai) — system admin đầu tiên tạo qua biến môi trường, xem SystemAdminBootstrap
--   * sửa các ràng buộc unique ở cuối file (soft delete, phạm vi công ty, NULL)
--
-- DB dev cũ (đã chạy V1–V117) KHÔNG nâng cấp được lên baseline này: cần xoá DB và tạo lại.
-- Từ đây trở đi mọi thay đổi schema là file V2, V3… như quy tắc thường.
-- =====================================================================

SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE `attendance_approve_leaves` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `attendance_id` bigint NOT NULL,
  `leave_request_id` bigint NOT NULL,
  `leave_type_name` varchar(100) NOT NULL,
  `paid` tinyint(1) NOT NULL DEFAULT '0',
  `leave_hours` double NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `fk_aal_attendance` (`attendance_id`),
  KEY `fk_aal_leave` (`leave_request_id`),
  CONSTRAINT `fk_aal_attendance` FOREIGN KEY (`attendance_id`) REFERENCES `attendances` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_aal_leave` FOREIGN KEY (`leave_request_id`) REFERENCES `leave_requests` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `attendance_requests` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `employee_id` bigint NOT NULL,
  `shift_assignment_id` bigint DEFAULT NULL,
  `request_date` date NOT NULL,
  `request_type` varchar(20) NOT NULL,
  `requested_check_in` time DEFAULT NULL,
  `requested_check_out` time DEFAULT NULL,
  `requested_overtime_minutes` int DEFAULT NULL,
  `requested_overtime_scope` varchar(20) DEFAULT NULL,
  `requested_overtime_period` varchar(20) DEFAULT NULL,
  `applied` tinyint(1) NOT NULL DEFAULT '1',
  `note` text,
  `status` varchar(20) NOT NULL DEFAULT 'PENDING',
  `admin_note` text,
  `processed_by` bigint DEFAULT NULL,
  `processed_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `active_key` tinyint GENERATED ALWAYS AS ((case when (`status` in (_utf8mb4'PENDING',_utf8mb4'APPROVED')) then 1 else NULL end)) STORED,
  PRIMARY KEY (`id`),
  KEY `fk_attendance_request_processed_by` (`processed_by`),
  KEY `idx_attendance_request_employee_id` (`employee_id`),
  KEY `idx_attendance_request_shift_assignment_id` (`shift_assignment_id`),
  CONSTRAINT `fk_attendance_request_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_attendance_request_processed_by` FOREIGN KEY (`processed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_attendance_requests_shift_assignment` FOREIGN KEY (`shift_assignment_id`) REFERENCES `shift_assignments` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `attendances` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `employee_id` bigint NOT NULL,
  `shift_assignment_id` bigint DEFAULT NULL,
  `date` date NOT NULL,
  `check_in` datetime(6) DEFAULT NULL,
  `check_out` datetime(6) DEFAULT NULL,
  `status` enum('PRESENT','ABSENT','LATE','HALF_DAY','LEAVE') DEFAULT NULL,
  `note` text,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `approved` tinyint(1) NOT NULL DEFAULT '0',
  `approved_at` datetime DEFAULT NULL,
  `approved_by_id` bigint DEFAULT NULL,
  `snap_actual_hours` double DEFAULT NULL,
  `snap_day_hours` double DEFAULT NULL,
  `snap_day_ot` double DEFAULT NULL,
  `snap_night_hours` double DEFAULT NULL,
  `snap_night_ot` double DEFAULT NULL,
  `check_in_latitude` double DEFAULT NULL,
  `check_in_longitude` double DEFAULT NULL,
  `check_out_latitude` double DEFAULT NULL,
  `check_out_longitude` double DEFAULT NULL,
  `work_flags` varchar(120) DEFAULT NULL COMMENT 'Comma-separated flags: EARLY_IN,LATE_IN,EARLY_OUT,LATE_OUT,ON_TIME,OVERTIME,LEAVE',
  `override_check_in` time DEFAULT NULL,
  `override_check_out` time DEFAULT NULL,
  `override_break_minutes` int DEFAULT NULL,
  `override_ot_day_minutes` int DEFAULT NULL,
  `override_ot_night_minutes` int DEFAULT NULL,
  `override_note` varchar(255) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  `deleted_at` datetime DEFAULT NULL,
  `deleted_by_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_attendance_slot` (`employee_id`,`date`,`shift_assignment_id`),
  KEY `idx_attendance_date` (`date`),
  KEY `idx_attendance_emp` (`employee_id`),
  KEY `fk_att_approved_by` (`approved_by_id`),
  KEY `fk_attendance_shift_assignment` (`shift_assignment_id`),
  KEY `fk_attendance_deleted_by` (`deleted_by_id`),
  CONSTRAINT `fk_att_approved_by` FOREIGN KEY (`approved_by_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_attendance_deleted_by` FOREIGN KEY (`deleted_by_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_attendance_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`),
  CONSTRAINT `fk_attendance_shift_assignment` FOREIGN KEY (`shift_assignment_id`) REFERENCES `shift_assignments` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `companies` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(200) NOT NULL,
  `code` varchar(50) NOT NULL,
  `domain` varchar(100) DEFAULT NULL,
  `logo` varchar(255) DEFAULT NULL,
  `address` text,
  `phone` varchar(20) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `day_start_time` time NOT NULL DEFAULT '06:00:00',
  `day_end_time` time NOT NULL DEFAULT '22:00:00',
  `self_attendance_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `attendance_day_night_mode` tinyint(1) NOT NULL DEFAULT '0',
  `attendance_ot_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `leave_hours_per_day` decimal(10,2) NOT NULL DEFAULT '8.00',
  `check_in_latitude` double DEFAULT NULL,
  `check_in_longitude` double DEFAULT NULL,
  `check_in_radius_meters` int NOT NULL DEFAULT '100',
  `location_check_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `check_in_before_minutes` int NOT NULL DEFAULT '30',
  `check_in_after_minutes` int NOT NULL DEFAULT '30',
  `check_out_before_minutes` int NOT NULL DEFAULT '30',
  `check_out_after_minutes` int NOT NULL DEFAULT '30',
  `standard_work_days` int NOT NULL DEFAULT '22',
  `payroll_cutoff_day` int NOT NULL DEFAULT '1',
  `check_in_tolerance_minutes` int DEFAULT NULL,
  `check_out_tolerance_minutes` int DEFAULT NULL,
  `rounding_check_in_minutes` int DEFAULT NULL,
  `rounding_check_out_minutes` int DEFAULT NULL,
  `rounding_work_minutes` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `department_shifts` (
  `department_id` bigint NOT NULL,
  `shift_id` bigint NOT NULL,
  PRIMARY KEY (`department_id`,`shift_id`),
  KEY `fk_deptshift_shift` (`shift_id`),
  CONSTRAINT `fk_deptshift_dept` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_deptshift_shift` FOREIGN KEY (`shift_id`) REFERENCES `work_shifts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `departments` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `name` varchar(100) NOT NULL,
  `code` varchar(20) NOT NULL,
  `description` text,
  `manager_id` bigint DEFAULT NULL,
  `parent_id` bigint DEFAULT NULL,
  `level` int NOT NULL DEFAULT '0',
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `check_in_latitude` double DEFAULT NULL,
  `check_in_longitude` double DEFAULT NULL,
  `check_in_radius_meters` int NOT NULL DEFAULT '100',
  `check_in_tolerance_minutes` int DEFAULT NULL,
  `check_out_tolerance_minutes` int DEFAULT NULL,
  `rounding_check_in_minutes` int DEFAULT NULL,
  `rounding_check_out_minutes` int DEFAULT NULL,
  `rounding_work_minutes` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_department_company_code_deleted` (`company_id`,`code`,`deleted`),
  KEY `fk_dept_manager` (`manager_id`),
  KEY `fk_dept_parent` (`parent_id`),
  CONSTRAINT `fk_dept_company` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_dept_manager` FOREIGN KEY (`manager_id`) REFERENCES `employees` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_dept_parent` FOREIGN KEY (`parent_id`) REFERENCES `departments` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `employee_locations` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `employee_id` bigint NOT NULL,
  `name` varchar(100) NOT NULL,
  `latitude` double NOT NULL,
  `longitude` double NOT NULL,
  `radius_meters` int NOT NULL DEFAULT '100',
  PRIMARY KEY (`id`),
  KEY `idx_emp_loc_employee` (`employee_id`),
  CONSTRAINT `fk_emp_loc_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `employees` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `employee_code` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `full_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `email` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `phone` varchar(15) DEFAULT NULL,
  `personal_email` varchar(100) DEFAULT NULL,
  `avatar` varchar(255) DEFAULT NULL,
  `gender` enum('MALE','FEMALE','OTHER') NOT NULL,
  `date_of_birth` date DEFAULT NULL,
  `join_date` date NOT NULL,
  `leave_date` date DEFAULT NULL,
  `status` enum('ACTIVE','INACTIVE','ON_LEAVE') NOT NULL DEFAULT 'ACTIVE',
  `department_id` bigint NOT NULL,
  `position_id` bigint DEFAULT NULL,
  `address` text,
  `identity_card` varchar(20) DEFAULT NULL,
  `bank_account` varchar(30) DEFAULT NULL,
  `bank_name` varchar(100) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `salary_grade_id` bigint DEFAULT NULL,
  `contract_salary` decimal(15,2) DEFAULT NULL COMMENT 'LÆ°Æ¡ng cÆ¡ báº£n theo há»£p Ä‘á»“ng',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_employee_company_code_deleted` (`company_id`,`employee_code`,`deleted`),
  UNIQUE KEY `uq_employee_company_email_deleted` (`company_id`,`email`,`deleted`),
  KEY `fk_employee_pos` (`position_id`),
  KEY `idx_employee_dept` (`department_id`),
  KEY `idx_employee_status` (`status`),
  KEY `fk_emp_salary_grade` (`salary_grade_id`),
  CONSTRAINT `fk_emp_company` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_emp_salary_grade` FOREIGN KEY (`salary_grade_id`) REFERENCES `salary_grades` (`id`),
  CONSTRAINT `fk_employee_dept` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`),
  CONSTRAINT `fk_employee_pos` FOREIGN KEY (`position_id`) REFERENCES `positions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `excel_history` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `user_id` bigint DEFAULT NULL,
  `type` enum('EXPORT','IMPORT','REPORT') NOT NULL,
  `module` varchar(255) NOT NULL,
  `filename` varchar(255) NOT NULL,
  `file_url` varchar(1024) DEFAULT NULL,
  `ok_count` int DEFAULT NULL,
  `error_count` int DEFAULT NULL,
  `skip_count` int DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  KEY `idx_excel_history_company` (`company_id`),
  KEY `idx_excel_history_user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `fcm_notification_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `fcm_token` varchar(512) NOT NULL,
  `shift_name` varchar(100) NOT NULL,
  `shift_start` time NOT NULL,
  `work_date` date NOT NULL,
  `minutes_before` int NOT NULL,
  `status` varchar(20) NOT NULL COMMENT 'SUCCESS | FAILED',
  `error_message` varchar(500) DEFAULT NULL,
  `sent_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `formula_variables` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `name` varchar(50) NOT NULL,
  `label` varchar(100) NOT NULL,
  `expression` text NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `show_in_formula` tinyint(1) NOT NULL DEFAULT '1',
  `category` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_fv_company_name` (`company_id`,`name`),
  CONSTRAINT `fk_fv_company` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `leave_accrual_rules` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `department_id` bigint DEFAULT NULL,
  `name` varchar(100) NOT NULL,
  `frequency` enum('MONTHLY','YEARLY') NOT NULL,
  `day_of_month` int DEFAULT NULL,
  `month_of_year` int DEFAULT NULL,
  `min_tenure_years` int NOT NULL DEFAULT '0',
  `valid_from` date DEFAULT NULL,
  `valid_to` date DEFAULT NULL,
  `expire_after_days` int DEFAULT NULL,
  `active` tinyint(1) NOT NULL DEFAULT '1',
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `grant_days` decimal(10,2) DEFAULT NULL,
  `grant_hours` decimal(10,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_leave_rule_company` (`company_id`),
  KEY `idx_leave_rule_department_id` (`department_id`),
  CONSTRAINT `fk_leave_rule_company` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `fk_leave_rule_department` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `leave_grants` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `employee_id` bigint NOT NULL,
  `leave_type_id` bigint DEFAULT NULL,
  `source` enum('MANUAL','AUTO') NOT NULL,
  `granted_at` date NOT NULL,
  `valid_from` date DEFAULT NULL,
  `valid_to` date DEFAULT NULL,
  `note` varchar(500) DEFAULT NULL,
  `accrual_rule_id` bigint DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `grant_days` decimal(10,2) DEFAULT NULL,
  `grant_hours` decimal(10,2) DEFAULT NULL,
  `used_days` decimal(10,2) NOT NULL DEFAULT '0.00',
  `used_hours` decimal(10,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`id`),
  KEY `fk_leave_grant_company` (`company_id`),
  KEY `fk_leave_grant_employee` (`employee_id`),
  KEY `fk_leave_grant_type` (`leave_type_id`),
  KEY `fk_leave_grant_rule` (`accrual_rule_id`),
  CONSTRAINT `fk_leave_grant_company` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `fk_leave_grant_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`),
  CONSTRAINT `fk_leave_grant_rule` FOREIGN KEY (`accrual_rule_id`) REFERENCES `leave_accrual_rules` (`id`),
  CONSTRAINT `fk_leave_grant_type` FOREIGN KEY (`leave_type_id`) REFERENCES `leave_types` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `leave_requests` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `employee_id` bigint NOT NULL,
  `reason` varchar(500) DEFAULT NULL,
  `status` enum('PENDING','APPROVED','REJECTED','CANCELLED') NOT NULL DEFAULT 'PENDING',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `company_id` bigint NOT NULL,
  `leave_type_id` bigint NOT NULL,
  `mode` enum('DAY_RANGE','HOUR_RANGE') NOT NULL,
  `from_date` date NOT NULL,
  `to_date` date NOT NULL,
  `from_time` time DEFAULT NULL,
  `to_time` time DEFAULT NULL,
  `requested_amount` decimal(10,2) NOT NULL,
  `admin_note` varchar(500) DEFAULT NULL,
  `processed_by` bigint DEFAULT NULL,
  `processed_at` datetime(6) DEFAULT NULL,
  `applied` tinyint(1) NOT NULL DEFAULT '1',
  `parent_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_leave_req_company` (`company_id`),
  KEY `idx_leave_req_type` (`leave_type_id`),
  KEY `idx_leave_req_processed_by` (`processed_by`),
  KEY `fk_leave_requests_employee` (`employee_id`),
  KEY `idx_lr_parent` (`parent_id`),
  CONSTRAINT `fk_leave_requests_company` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `fk_leave_requests_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`),
  CONSTRAINT `fk_leave_requests_processed_by` FOREIGN KEY (`processed_by`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_leave_requests_type` FOREIGN KEY (`leave_type_id`) REFERENCES `leave_types` (`id`),
  CONSTRAINT `fk_lr_parent` FOREIGN KEY (`parent_id`) REFERENCES `leave_requests` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `leave_types` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `code` varchar(50) NOT NULL,
  `name` varchar(100) NOT NULL,
  `unit` enum('DAY','HOUR') NOT NULL,
  `deduct_per_day` decimal(10,2) NOT NULL DEFAULT '1.00',
  `is_paid` tinyint(1) NOT NULL DEFAULT '1',
  `active` tinyint(1) NOT NULL DEFAULT '1',
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  `description` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_leave_type_company_code` (`company_id`,`code`),
  CONSTRAINT `fk_leave_type_company` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `payrolls` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `employee_id` bigint NOT NULL,
  `year` int NOT NULL,
  `month` int NOT NULL,
  `base_salary` decimal(15,2) NOT NULL,
  `allowance` decimal(15,2) NOT NULL DEFAULT '0.00',
  `bonus` decimal(15,2) NOT NULL DEFAULT '0.00',
  `overtime_pay` decimal(15,2) NOT NULL DEFAULT '0.00',
  `gross_salary` decimal(15,2) NOT NULL,
  `social_insurance` decimal(15,2) NOT NULL,
  `health_insurance` decimal(15,2) NOT NULL,
  `unemployment_insurance` decimal(15,2) NOT NULL,
  `personal_income_tax` decimal(15,2) NOT NULL,
  `other_deductions` decimal(15,2) NOT NULL DEFAULT '0.00',
  `net_salary` decimal(15,2) NOT NULL,
  `status` enum('DRAFT','APPROVED','PAID') NOT NULL DEFAULT 'DRAFT',
  `note` text,
  `paid_at` datetime(6) DEFAULT NULL,
  `approved_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `present_days` int DEFAULT NULL,
  `total_overtime_hours` decimal(8,2) DEFAULT NULL,
  `custom_deductions` json DEFAULT NULL,
  `day_hours` decimal(8,2) DEFAULT NULL,
  `night_hours` decimal(8,2) DEFAULT NULL,
  `day_ot` decimal(8,2) DEFAULT NULL,
  `night_ot` decimal(8,2) DEFAULT NULL,
  `pay_type` varchar(10) DEFAULT NULL,
  `standard_work_days` int DEFAULT NULL,
  `period_from` date DEFAULT NULL,
  `period_to` date DEFAULT NULL,
  `income_entries` json DEFAULT NULL COMMENT 'Thu nháº­p thÃªm snapshot: {"VAR": {label, amount}}',
  `allowance_entries` json DEFAULT NULL COMMENT 'Trá»£ cáº¥p snapshot: {"VAR": {label, amount}}',
  `custom_formula` json DEFAULT NULL COMMENT 'Inline formula snapshot, chá»‰ Ã¡p dá»¥ng cho payroll nÃ y',
  `salary_grade_id` bigint DEFAULT NULL,
  `salary_grade_code` varchar(50) DEFAULT NULL,
  `salary_grade_name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_payroll` (`employee_id`,`year`,`month`),
  KEY `idx_payroll_month` (`year`,`month`),
  KEY `fk_payroll_salary_grade` (`salary_grade_id`),
  CONSTRAINT `fk_payroll_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`),
  CONSTRAINT `fk_payroll_salary_grade` FOREIGN KEY (`salary_grade_id`) REFERENCES `salary_grades` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `permissions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `code` varchar(50) NOT NULL,
  `description` varchar(200) NOT NULL,
  `module` varchar(50) NOT NULL,
  `required_rule` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `positions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `code` varchar(20) NOT NULL,
  `department_id` bigint NOT NULL,
  `description` text,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_position_code_deleted` (`code`,`deleted`),
  KEY `fk_position_dept` (`department_id`),
  CONSTRAINT `fk_position_dept` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `profile_edit_requests` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `employee_id` bigint NOT NULL,
  `full_name` varchar(100) DEFAULT NULL,
  `gender` enum('MALE','FEMALE','OTHER') DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `phone` varchar(15) DEFAULT NULL,
  `personal_email` varchar(100) DEFAULT NULL,
  `avatar_url` varchar(255) DEFAULT NULL,
  `status` enum('PENDING','APPROVED','REJECTED','CANCELLED') NOT NULL DEFAULT 'PENDING',
  `admin_note` text,
  `processed_by` bigint DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_per_employee` (`employee_id`),
  KEY `fk_per_admin` (`processed_by`),
  CONSTRAINT `fk_per_admin` FOREIGN KEY (`processed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_per_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `role_permission_dept_scopes` (
  `role_id` bigint NOT NULL,
  `permission_code` varchar(50) NOT NULL,
  `department_id` bigint NOT NULL,
  PRIMARY KEY (`role_id`,`permission_code`,`department_id`),
  KEY `fk_rpds_dept` (`department_id`),
  CONSTRAINT `fk_rpds_role` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `role_permissions` (
  `role_id` bigint NOT NULL,
  `permission_id` bigint NOT NULL,
  PRIMARY KEY (`role_id`,`permission_id`),
  KEY `fk_rp_perm` (`permission_id`),
  CONSTRAINT `fk_rp_perm` FOREIGN KEY (`permission_id`) REFERENCES `permissions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_rp_role` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `roles` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `name` varchar(100) NOT NULL,
  `description` varchar(200) DEFAULT NULL,
  `is_default` tinyint(1) NOT NULL DEFAULT '0',
  `role_view_all_company` tinyint(1) NOT NULL DEFAULT '1',
  `role_view_department_id` bigint DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_role_company_name_deleted` (`company_id`,`name`,`deleted`),
  KEY `idx_role_company_name` (`company_id`,`name`),
  KEY `idx_role_view_department` (`role_view_department_id`),
  CONSTRAINT `fk_role_company` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_role_view_department` FOREIGN KEY (`role_view_department_id`) REFERENCES `departments` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `salary_formulas` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `effective_date` date NOT NULL,
  `expression_gross` text NOT NULL,
  `expression_net` text NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `salary_grade_id` bigint NOT NULL,
  `name` varchar(100) NOT NULL,
  `custom_vars` json DEFAULT NULL COMMENT 'Private variables: {"VAR_NAME": "expression", ...}',
  `deduction_vars` json DEFAULT NULL,
  `income_vars` json DEFAULT NULL COMMENT 'Thu nháº­p thÃªm: {"VAR": {label, expression}}',
  `allowance_vars` json DEFAULT NULL COMMENT 'Trá»£ cáº¥p: {"VAR": {label, expression}}',
  PRIMARY KEY (`id`),
  KEY `idx_sf_grade_date` (`salary_grade_id`,`effective_date` DESC),
  CONSTRAINT `fk_sf_grade` FOREIGN KEY (`salary_grade_id`) REFERENCES `salary_grades` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `salary_grades` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `code` varchar(20) NOT NULL,
  `name` varchar(100) NOT NULL,
  `pay_type` enum('DAILY','HOURLY') NOT NULL DEFAULT 'DAILY',
  `base_rate` decimal(15,2) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `department_id` bigint DEFAULT NULL,
  `company_id` bigint DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_sg_dept_code` (`department_id`,`code`),
  KEY `idx_sg_department` (`department_id`),
  KEY `fk_salary_grade_company` (`company_id`),
  CONSTRAINT `fk_salary_grade_company` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `fk_sg_department` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `salary_histories` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `employee_id` bigint NOT NULL,
  `base_salary` decimal(15,2) NOT NULL,
  `effective_date` date NOT NULL,
  `note` text,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_salary_history_employee_date` (`employee_id`,`effective_date` DESC),
  CONSTRAINT `fk_salary_history_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `shift_assignments` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `employee_id` bigint NOT NULL,
  `shift_id` bigint DEFAULT NULL,
  `work_date` date NOT NULL,
  `note` varchar(255) DEFAULT NULL,
  `custom_start_time` time DEFAULT NULL,
  `custom_end_time` time DEFAULT NULL,
  `custom_break_start` time DEFAULT NULL,
  `custom_break_end` time DEFAULT NULL,
  `created_by` bigint DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  `approved` tinyint(1) NOT NULL DEFAULT '0',
  `snapshot_name` varchar(100) DEFAULT NULL,
  `snapshot_code` varchar(20) DEFAULT NULL,
  `snapshot_start_time` time DEFAULT NULL,
  `snapshot_end_time` time DEFAULT NULL,
  `snapshot_break_start` time DEFAULT NULL,
  `snapshot_break_end` time DEFAULT NULL,
  `snapshot_work_minutes` int DEFAULT NULL,
  `snapshot_color` varchar(7) DEFAULT NULL,
  `reminder_sent_at` datetime DEFAULT NULL,
  `check_in_notif_sent_at` datetime DEFAULT NULL,
  `check_out_notif_sent_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_assign_employee` (`employee_id`),
  KEY `idx_assign_date` (`work_date`),
  KEY `fk_assign_shift` (`shift_id`),
  CONSTRAINT `fk_assign_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_assign_shift` FOREIGN KEY (`shift_id`) REFERENCES `work_shifts` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `system_admins` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `email` varchar(100) NOT NULL,
  `password` varchar(255) NOT NULL,
  `name` varchar(100) NOT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `user_permission_dept_scopes` (
  `user_id` bigint NOT NULL,
  `permission_code` varchar(50) NOT NULL,
  `department_id` bigint NOT NULL,
  PRIMARY KEY (`user_id`,`permission_code`,`department_id`),
  KEY `fk_upds_dept` (`department_id`),
  CONSTRAINT `fk_upds_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `user_permissions` (
  `user_id` bigint NOT NULL,
  `permission_id` bigint NOT NULL,
  PRIMARY KEY (`user_id`,`permission_id`),
  KEY `fk_up_perm` (`permission_id`),
  CONSTRAINT `fk_up_perm` FOREIGN KEY (`permission_id`) REFERENCES `permissions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_up_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `user_roles` (
  `user_id` bigint NOT NULL,
  `role_id` bigint NOT NULL,
  PRIMARY KEY (`user_id`,`role_id`),
  KEY `fk_ur_role` (`role_id`),
  CONSTRAINT `fk_ur_role` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_ur_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `user_sessions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `jti` varchar(36) NOT NULL COMMENT 'JWT ID of the refresh token',
  `device_id` varchar(255) NOT NULL,
  `expires_at` datetime NOT NULL,
  `revoked` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_jti` (`jti`),
  KEY `idx_session_user` (`user_id`),
  CONSTRAINT `fk_session_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `users` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `email` varchar(100) NOT NULL,
  `password` varchar(255) NOT NULL,
  `employee_id` bigint DEFAULT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT '1',
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `fcm_token` varchar(512) DEFAULT NULL,
  `shift_reminder_minutes` int DEFAULT NULL,
  `check_in_out_notif_minutes` int DEFAULT NULL COMMENT 'Sá»‘ phÃºt trÆ°á»›c ca (check-in) / sau ca (check-out) Ä‘á»ƒ gá»­i thÃ´ng bÃ¡o. NULL = táº¯t',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_user_email_deleted` (`email`,`deleted`),
  UNIQUE KEY `employee_id` (`employee_id`),
  KEY `fk_user_company` (`company_id`),
  CONSTRAINT `fk_user_company` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_user_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `work_shifts` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `name` varchar(100) NOT NULL,
  `code` varchar(20) NOT NULL,
  `start_time` time DEFAULT NULL,
  `end_time` time DEFAULT NULL,
  `break_start` time DEFAULT NULL,
  `break_end` time DEFAULT NULL,
  `work_minutes` int DEFAULT NULL,
  `color` varchar(7) NOT NULL DEFAULT '#1976D2',
  `active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `group_name` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_company_code_active` (`company_id`,`code`,`active`),
  KEY `idx_shift_company` (`company_id`),
  CONSTRAINT `fk_shift_company` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- Ràng buộc unique chỉ áp cho bản ghi còn hiệu lực
--
-- Cũ: unique (…, code, deleted) với deleted là boolean → chỉ cho xoá mềm 1 lần;
-- tạo lại rồi xoá lần 2 cùng mã thì lỗi trùng. Mới: cột sinh *_key = NULL khi đã xoá
-- (MySQL cho phép nhiều NULL trong unique), = mã khi còn hiệu lực.
-- ---------------------------------------------------------------------

-- Phòng ban: mã duy nhất trong công ty
ALTER TABLE departments
    DROP INDEX uk_department_company_code_deleted,
    ADD COLUMN code_key VARCHAR(20) GENERATED ALWAYS AS (IF(deleted, NULL, code)) VIRTUAL,
    ADD UNIQUE KEY uq_department_company_code (company_id, code_key);

-- Nhân viên: mã và email duy nhất trong công ty
ALTER TABLE employees
    DROP INDEX uq_employee_company_code_deleted,
    DROP INDEX uq_employee_company_email_deleted,
    ADD COLUMN code_key VARCHAR(20) GENERATED ALWAYS AS (IF(deleted, NULL, employee_code)) VIRTUAL,
    ADD COLUMN email_key VARCHAR(100) GENERATED ALWAYS AS (IF(deleted, NULL, email)) VIRTUAL,
    ADD UNIQUE KEY uq_employee_company_code (company_id, code_key),
    ADD UNIQUE KEY uq_employee_company_email (company_id, email_key);

-- Chức vụ: trước đây unique (code, deleted) trên TOÀN HỆ THỐNG → công ty B không tạo
-- được mã chức vụ mà công ty A đã dùng. Quy tắc "mã duy nhất trong công ty" kiểm ở
-- PositionService; DB chỉ chặn trùng trong cùng phòng ban.
ALTER TABLE positions
    DROP INDEX uk_position_code_deleted,
    ADD COLUMN code_key VARCHAR(20) GENERATED ALWAYS AS (IF(deleted, NULL, code)) VIRTUAL,
    ADD UNIQUE KEY uq_position_department_code (department_id, code_key);

-- Vai trò: tên duy nhất trong công ty
ALTER TABLE roles
    DROP INDEX uq_role_company_name_deleted,
    ADD COLUMN name_key VARCHAR(100) GENERATED ALWAYS AS (IF(deleted, NULL, name)) VIRTUAL,
    ADD UNIQUE KEY uq_role_company_name (company_id, name_key);

-- Tài khoản: email đăng nhập duy nhất toàn hệ thống (đăng nhập chỉ bằng email)
ALTER TABLE users
    DROP INDEX uq_user_email_deleted,
    ADD COLUMN email_key VARCHAR(100) GENERATED ALWAYS AS (IF(deleted, NULL, email)) VIRTUAL,
    ADD UNIQUE KEY uq_user_email (email_key);

-- Ca làm việc: active = false là đã xoá
ALTER TABLE work_shifts
    DROP INDEX uk_company_code_active,
    ADD COLUMN code_key VARCHAR(20) GENERATED ALWAYS AS (IF(active, code, NULL)) VIRTUAL,
    ADD UNIQUE KEY uq_work_shift_company_code (company_id, code_key);

-- Loại phép: trước đây không tính deleted → không tạo lại được mã đã xoá
ALTER TABLE leave_types
    DROP INDEX uk_leave_type_company_code,
    ADD COLUMN code_key VARCHAR(50) GENERATED ALWAYS AS (IF(deleted, NULL, code)) VIRTUAL,
    ADD UNIQUE KEY uq_leave_type_company_code (company_id, code_key);

-- Bậc lương: bậc chung toàn công ty có department_id NULL → unique cũ không chặn trùng
ALTER TABLE salary_grades
    DROP INDEX uq_sg_dept_code,
    ADD COLUMN grade_key VARCHAR(80) GENERATED ALWAYS AS
        (IF(deleted, NULL, CONCAT(IFNULL(department_id, 0), ':', code))) VIRTUAL,
    ADD UNIQUE KEY uq_salary_grade_company_key (company_id, grade_key);

-- Chấm công (A9): unique cũ (employee_id, date, shift_assignment_id) không chặn được
-- 2 dòng cùng ngày khi shift_assignment_id NULL. Dòng không gắn ca dùng khoá 0.
ALTER TABLE attendances
    DROP INDEX uq_attendance_slot,
    ADD COLUMN slot_key BIGINT GENERATED ALWAYS AS
        (IF(deleted, NULL, IFNULL(shift_assignment_id, 0))) VIRTUAL,
    ADD UNIQUE KEY uq_attendance_slot (employee_id, date, slot_key);

-- ---------------------------------------------------------------------
-- Dữ liệu tham chiếu: danh mục quyền (dùng chung mọi công ty)
-- ---------------------------------------------------------------------
INSERT INTO permissions (code, description, module, required_rule) VALUES
('DASHBOARD_VIEW', 'Hiển thị mục Tổng quan trên menu', 'DASHBOARD', NULL),
('EMPLOYEE_VIEW', 'Xem danh sách nhân viên', 'EMPLOYEE', NULL),
('EMPLOYEE_CREATE', 'Thêm nhân viên mới', 'EMPLOYEE', 'EMPLOYEE_VIEW'),
('EMPLOYEE_UPDATE', 'Cập nhật thông tin nhân viên', 'EMPLOYEE', 'EMPLOYEE_VIEW'),
('EMPLOYEE_DELETE', 'Xóa/vô hiệu hóa nhân viên', 'EMPLOYEE', 'EMPLOYEE_VIEW'),
('DEPARTMENT_VIEW', 'Xem cơ cấu phòng ban', 'DEPARTMENT', NULL),
('DEPARTMENT_MANAGE', 'Tạo/sửa/xóa phòng ban', 'DEPARTMENT', 'DEPARTMENT_VIEW'),
('ATTENDANCE_VIEW', 'Xem dữ liệu chấm công', 'ATTENDANCE', NULL),
('ATTENDANCE_MANAGE', 'Chỉnh sửa chấm công', 'ATTENDANCE', 'ATTENDANCE_VIEW'),
('SHIFT_VIEW', 'Xem ca làm', 'SHIFT', NULL),
('SHIFT_MANAGE', 'Quản lý ca làm', 'SHIFT', 'SHIFT_VIEW'),
('PAYROLL_VIEW', 'Xem bảng lương', 'PAYROLL', NULL),
('PAYROLL_CREATE', 'Tạo bảng lương', 'PAYROLL', 'PAYROLL_VIEW'),
('PAYROLL_APPROVE', 'Phê duyệt bảng lương', 'PAYROLL', 'PAYROLL_VIEW'),
('PAYROLL_PAY', 'Đánh dấu đã thanh toán lương', 'PAYROLL', 'PAYROLL_VIEW'),
('ROLE_VIEW', 'Xem danh sách vai trò', 'ROLE', NULL),
('ROLE_MANAGE', 'Tạo/sửa/xóa vai trò', 'ROLE', 'ROLE_VIEW'),
('USER_MANAGE', 'Quản lý tài khoản người dùng', 'USER', NULL),
('COMPANY_MANAGE', 'Toàn quyền quản trị công ty', 'COMPANY', NULL),
('POSITION_MANAGE', 'Tạo/sửa/xóa chức vụ', 'DEPARTMENT', 'DEPARTMENT_VIEW'),
('ATTENDANCE_SELF', 'Tự check-in/check-out', 'ATTENDANCE', 'ATTENDANCE_VIEW'),
('ATTENDANCE_REQUEST_APPROVE', 'Duyệt yêu cầu chấm công', 'ATTENDANCE', 'ATTENDANCE_VIEW'),
('ATTENDANCE_APPROVE', 'Duyệt / bỏ duyệt bảng công', 'ATTENDANCE', 'ATTENDANCE_VIEW'),
('LEAVE_VIEW', 'Xem đơn nghỉ và số phép', 'LEAVE', NULL),
('LEAVE_REQUEST_CREATE', 'Tạo đơn nghỉ', 'LEAVE', 'LEAVE_VIEW'),
('LEAVE_REQUEST_APPROVE', 'Duyệt/Từ chối đơn nghỉ', 'LEAVE', 'LEAVE_VIEW'),
('LEAVE_TYPE_MANAGE', 'Quản lý loại nghỉ', 'LEAVE', 'LEAVE_TYPE_VIEW'),
('LEAVE_GRANT_MANUAL', 'Cấp phép thủ công', 'LEAVE', 'LEAVE_VIEW'),
('LEAVE_ACCRUAL_MANAGE', 'Quản lý rule cộng phép tự động', 'LEAVE', 'LEAVE_ACCRUAL_VIEW'),
('COMPANY_SETTING_VIEW', 'Xem cài đặt chung công ty', 'COMPANY_SETTING', NULL),
('COMPANY_SETTING_MANAGE', 'Quản lý cài đặt chung công ty', 'COMPANY_SETTING', NULL),
('LEAVE_TYPE_VIEW', 'Xem danh sách loại nghỉ', 'LEAVE', 'LEAVE_VIEW'),
('LEAVE_ACCRUAL_VIEW', 'Xem cài đặt rule cộng phép', 'LEAVE', 'LEAVE_VIEW'),
('LEAVE_REQUEST_CREATE_FOR_OTHERS', 'Tạo đơn nghỉ phép hộ nhân viên khác', 'LEAVE', 'LEAVE_REQUEST_CREATE'),
('REPORT_VIEW', 'Xem và xuất báo cáo nhân sự', 'REPORT', NULL);
