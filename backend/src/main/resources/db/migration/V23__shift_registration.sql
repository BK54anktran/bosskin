-- Đăng ký lịch làm việc (thiết kế docs/thiet-ke/dang-ky-ca.md).
--
-- Công ty bật / tắt chức năng (companies.shift_registration_enabled, mặc định tắt).
-- Quản lý tạo đợt (khoảng ngày bất kỳ ≤ 62 ngày, phòng ban, hạn chót), mở / đóng; nhân viên trong phòng ban của đợt
-- đăng ký từng ngày: theo ca có sẵn (SHIFT), giờ tuỳ chỉnh (CUSTOM) hoặc rảnh cả ngày — xếp sao cũng được (ANY).
-- Mỗi ngày ≤ 2 khung (ANY chỉ 1). Quản lý duyệt theo ngày / từng ô → tạo phân ca (shift_assignments); ANY cần quản lý chọn ca.
ALTER TABLE companies ADD COLUMN shift_registration_enabled tinyint(1) NOT NULL DEFAULT 0;

CREATE TABLE shift_registration_rounds (
  id bigint NOT NULL AUTO_INCREMENT,
  company_id bigint NOT NULL,
  name varchar(100) NOT NULL,
  from_date date NOT NULL,
  to_date date NOT NULL,
  status enum('DRAFT','OPEN','CLOSED') NOT NULL DEFAULT 'DRAFT',
  closes_at datetime(6) DEFAULT NULL,
  earliest_time time DEFAULT NULL,
  latest_time time DEFAULT NULL,
  min_hours decimal(4,2) DEFAULT NULL,
  max_hours decimal(4,2) DEFAULT NULL,
  min_days int DEFAULT NULL,
  needed_per_day int DEFAULT NULL,
  note varchar(500) DEFAULT NULL,
  created_by bigint DEFAULT NULL,
  deleted tinyint(1) NOT NULL DEFAULT 0,
  created_at datetime(6) NOT NULL,
  updated_at datetime(6) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_shift_reg_round_company (company_id, status, from_date),
  CONSTRAINT fk_shift_reg_round_company FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE,
  CONSTRAINT fk_shift_reg_round_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE shift_registration_round_departments (
  round_id bigint NOT NULL,
  department_id bigint NOT NULL,
  PRIMARY KEY (round_id, department_id),
  KEY idx_shift_reg_round_dept (department_id),
  CONSTRAINT fk_shift_reg_round_dept_round FOREIGN KEY (round_id) REFERENCES shift_registration_rounds (id) ON DELETE CASCADE,
  CONSTRAINT fk_shift_reg_round_dept_dept FOREIGN KEY (department_id) REFERENCES departments (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- kind: SHIFT (shift_id + giờ chụp lại của ca) | CUSTOM (start/end) | ANY (start/end NULL).
-- status: PENDING → APPROVED (assignment_id = phân ca đã tạo) | REJECTED.
CREATE TABLE shift_registrations (
  id bigint NOT NULL AUTO_INCREMENT,
  round_id bigint NOT NULL,
  employee_id bigint NOT NULL,
  work_date date NOT NULL,
  kind enum('SHIFT','CUSTOM','ANY') NOT NULL,
  shift_id bigint DEFAULT NULL,
  start_time time DEFAULT NULL,
  end_time time DEFAULT NULL,
  note varchar(255) DEFAULT NULL,
  status enum('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING',
  assignment_id bigint DEFAULT NULL,
  decided_by bigint DEFAULT NULL,
  decided_at datetime(6) DEFAULT NULL,
  deleted tinyint(1) NOT NULL DEFAULT 0,
  created_at datetime(6) NOT NULL,
  updated_at datetime(6) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_shift_reg_round_date (round_id, work_date),
  KEY idx_shift_reg_employee_date (employee_id, work_date),
  CONSTRAINT fk_shift_reg_round FOREIGN KEY (round_id) REFERENCES shift_registration_rounds (id) ON DELETE CASCADE,
  CONSTRAINT fk_shift_reg_employee FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
  CONSTRAINT fk_shift_reg_shift FOREIGN KEY (shift_id) REFERENCES work_shifts (id) ON DELETE SET NULL,
  CONSTRAINT fk_shift_reg_assignment FOREIGN KEY (assignment_id) REFERENCES shift_assignments (id) ON DELETE SET NULL,
  CONSTRAINT fk_shift_reg_decided_by FOREIGN KEY (decided_by) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO permissions (code, description, module, required_rule) VALUES
('SHIFT_REGISTRATION_SELF', 'Tự đăng ký lịch làm việc (khi công ty bật)', 'SHIFT', NULL),
('SHIFT_REGISTRATION_MANAGE', 'Tạo / mở / đóng đợt đăng ký lịch, duyệt đăng ký thành phân ca', 'SHIFT', 'SHIFT_VIEW');

-- Admin: cả hai quyền. Vai trò mặc định của nhân viên: tự đăng ký.
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code IN ('SHIFT_REGISTRATION_SELF', 'SHIFT_REGISTRATION_MANAGE')
WHERE r.name = 'Admin' AND r.deleted = 0;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code = 'SHIFT_REGISTRATION_SELF'
WHERE r.is_default = 1 AND r.deleted = 0 AND r.name <> 'Admin';
