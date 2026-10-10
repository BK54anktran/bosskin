-- Bước M: thông tin thuế / bảo hiểm của nhân viên, người phụ thuộc, phần bảo hiểm công ty đóng.

ALTER TABLE employees
  ADD COLUMN tax_code varchar(20) DEFAULT NULL,
  ADD COLUMN social_insurance_no varchar(20) DEFAULT NULL,
  ADD COLUMN health_insurance_place varchar(255) DEFAULT NULL,
  ADD COLUMN insurance_join_date date DEFAULT NULL;

-- Người phụ thuộc. Giảm trừ tính theo tháng: deduction_from / deduction_to lưu ngày 01 của tháng,
-- deduction_to NULL = chưa kết thúc. Chỉ PENDING (đã nộp, chờ MST) và REGISTERED được tính giảm trừ.
CREATE TABLE employee_dependents (
  id bigint NOT NULL AUTO_INCREMENT,
  company_id bigint NOT NULL,
  employee_id bigint NOT NULL,
  full_name varchar(100) NOT NULL,
  relationship enum('CHILD','SPOUSE','PARENT','OTHER') NOT NULL,
  date_of_birth date DEFAULT NULL,
  tax_code varchar(20) DEFAULT NULL,
  identity_no varchar(20) DEFAULT NULL,
  deduction_from date NOT NULL,
  deduction_to date DEFAULT NULL,
  registration_status enum('NOT_REGISTERED','PENDING','REGISTERED') NOT NULL DEFAULT 'PENDING',
  note varchar(500) DEFAULT NULL,
  deleted tinyint(1) NOT NULL DEFAULT 0,
  created_at datetime(6) NOT NULL,
  updated_at datetime(6) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_dependent_employee (employee_id, deleted),
  KEY idx_dependent_company (company_id, deleted),
  CONSTRAINT fk_dependent_employee FOREIGN KEY (employee_id) REFERENCES employees (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tỷ lệ bảo hiểm công ty đóng (mặc định BHXH 17.5% gồm TNLĐ-BNN 0.5%, BHYT 3%, BHTN 1%)
ALTER TABLE companies
  ADD COLUMN employer_social_rate decimal(6,4) NOT NULL DEFAULT 0.1750,
  ADD COLUMN employer_health_rate decimal(6,4) NOT NULL DEFAULT 0.0300,
  ADD COLUMN employer_unemployment_rate decimal(6,4) NOT NULL DEFAULT 0.0100;

-- Snapshot trên phiếu lương: số người phụ thuộc và phần bảo hiểm công ty đóng
ALTER TABLE payrolls
  ADD COLUMN dependents int DEFAULT NULL,
  ADD COLUMN employer_social_ins decimal(15,2) DEFAULT NULL,
  ADD COLUMN employer_health_ins decimal(15,2) DEFAULT NULL,
  ADD COLUMN employer_unemployment_ins decimal(15,2) DEFAULT NULL;

-- Xem CCCD, tài khoản ngân hàng, MST, số sổ BHXH (không có quyền → hiện dạng che ****1234)
INSERT INTO permissions (code, description, module, required_rule) VALUES
('EMPLOYEE_SENSITIVE_VIEW', 'Xem dữ liệu nhạy cảm của nhân viên (CCCD, tài khoản NH, MST, sổ BHXH)', 'EMPLOYEE', 'EMPLOYEE_VIEW');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code = 'EMPLOYEE_SENSITIVE_VIEW'
WHERE r.name = 'Admin' AND r.deleted = 0;
