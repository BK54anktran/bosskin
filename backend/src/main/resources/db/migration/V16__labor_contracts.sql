-- Bước L: hợp đồng lao động, phụ lục, phụ cấp.
--
-- Trạng thái lưu: DRAFT (nháp) | ACTIVE (hiệu lực) | TERMINATED (chấm dứt). "Hết hạn" không lưu mà suy ra:
-- ACTIVE có end_date < hôm nay. Hai hợp đồng không nháp của cùng nhân viên không được chồng ngày (kiểm ở ContractService).
-- Lương hiệu lực ở một ngày = phụ lục mới nhất có effective_from <= ngày (trường NULL = giữ giá trị trước đó),
-- không có phụ lục → giá trị của hợp đồng. Phụ cấp: phụ lục overrides_allowances = 1 thay cả bộ phụ cấp.
CREATE TABLE labor_contracts (
  id bigint NOT NULL AUTO_INCREMENT,
  company_id bigint NOT NULL,
  employee_id bigint NOT NULL,
  contract_no varchar(50) NOT NULL,
  contract_type enum('PROBATION','FIXED_TERM','INDEFINITE','SEASONAL','SERVICE') NOT NULL,
  status enum('DRAFT','ACTIVE','TERMINATED') NOT NULL DEFAULT 'DRAFT',
  sign_date date DEFAULT NULL,
  start_date date NOT NULL,
  end_date date DEFAULT NULL,
  base_salary decimal(15,2) NOT NULL,
  insurance_salary decimal(15,2) DEFAULT NULL,
  position_title varchar(150) DEFAULT NULL,
  note varchar(1000) DEFAULT NULL,
  termination_date date DEFAULT NULL,
  termination_reason varchar(500) DEFAULT NULL,
  created_by bigint DEFAULT NULL,
  deleted tinyint(1) NOT NULL DEFAULT 0,
  created_at datetime(6) NOT NULL,
  updated_at datetime(6) NOT NULL,
  contract_no_key varchar(50) GENERATED ALWAYS AS (IF(deleted = 0, contract_no, NULL)) STORED,
  PRIMARY KEY (id),
  UNIQUE KEY uk_labor_contract_no (company_id, contract_no_key),
  KEY idx_labor_contract_employee (employee_id, start_date),
  KEY idx_labor_contract_end (company_id, status, end_date),
  CONSTRAINT fk_labor_contract_company FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE,
  CONSTRAINT fk_labor_contract_employee FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
  CONSTRAINT fk_labor_contract_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE contract_appendices (
  id bigint NOT NULL AUTO_INCREMENT,
  contract_id bigint NOT NULL,
  appendix_no varchar(50) NOT NULL,
  effective_from date NOT NULL,
  base_salary decimal(15,2) DEFAULT NULL,
  insurance_salary decimal(15,2) DEFAULT NULL,
  position_title varchar(150) DEFAULT NULL,
  overrides_allowances tinyint(1) NOT NULL DEFAULT 0,
  note varchar(1000) DEFAULT NULL,
  deleted tinyint(1) NOT NULL DEFAULT 0,
  created_at datetime(6) NOT NULL,
  updated_at datetime(6) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_contract_appendix (contract_id, effective_from),
  CONSTRAINT fk_contract_appendix_contract FOREIGN KEY (contract_id) REFERENCES labor_contracts (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- appendix_id NULL = phụ cấp của hợp đồng gốc. code → biến lương ALLOWANCE_<code>.
CREATE TABLE contract_allowances (
  id bigint NOT NULL AUTO_INCREMENT,
  contract_id bigint NOT NULL,
  appendix_id bigint DEFAULT NULL,
  code varchar(30) NOT NULL,
  name varchar(150) NOT NULL,
  amount decimal(15,2) NOT NULL,
  insurable tinyint(1) NOT NULL DEFAULT 0,
  taxable tinyint(1) NOT NULL DEFAULT 1,
  created_at datetime(6) NOT NULL,
  updated_at datetime(6) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_contract_allowance (contract_id, appendix_id),
  CONSTRAINT fk_contract_allowance_contract FOREIGN KEY (contract_id) REFERENCES labor_contracts (id) ON DELETE CASCADE,
  CONSTRAINT fk_contract_allowance_appendix FOREIGN KEY (appendix_id) REFERENCES contract_appendices (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Số ngày báo trước hợp đồng sắp hết hạn
ALTER TABLE companies ADD COLUMN contract_expiry_warning_days int NOT NULL DEFAULT 30;

-- Chuyển lương HĐ hiện có thành một hợp đồng không xác định thời hạn đang hiệu lực từ ngày vào làm.
-- employees.contract_salary giữ lại làm dự phòng cho nhân viên chưa có hợp đồng và được đồng bộ theo hợp đồng.
INSERT INTO labor_contracts (company_id, employee_id, contract_no, contract_type, status, sign_date, start_date,
                             base_salary, note, created_at, updated_at)
SELECT e.company_id, e.id, CONCAT('HD-', e.employee_code), 'INDEFINITE', 'ACTIVE', e.join_date, e.join_date,
       e.contract_salary, 'V16', NOW(6), NOW(6)
FROM employees e
WHERE e.deleted = 0 AND e.contract_salary IS NOT NULL AND e.contract_salary > 0;

INSERT INTO permissions (code, description, module, required_rule) VALUES
('CONTRACT_VIEW', 'Xem hợp đồng lao động', 'CONTRACT', NULL),
('CONTRACT_EDIT', 'Tạo / sửa hợp đồng lao động và phụ lục', 'CONTRACT', 'CONTRACT_VIEW'),
('CONTRACT_DELETE', 'Xoá hợp đồng lao động', 'CONTRACT', 'CONTRACT_VIEW');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code IN ('CONTRACT_VIEW', 'CONTRACT_EDIT', 'CONTRACT_DELETE')
WHERE r.name = 'Admin' AND r.deleted = 0;
