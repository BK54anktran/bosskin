-- Bước N: tài liệu nhân sự. File lưu riêng tư (S3 không công khai hoặc thư mục cục bộ khi chạy dev / test),
-- chỉ trả link ký tạm vài phút; mỗi lần lấy link ghi nhật ký DOCUMENT_VIEW.

-- Danh mục loại tài liệu do công ty cấu hình
CREATE TABLE document_types (
  id bigint NOT NULL AUTO_INCREMENT,
  company_id bigint NOT NULL,
  code varchar(30) NOT NULL,
  name varchar(150) NOT NULL,
  required tinyint(1) NOT NULL DEFAULT 0,
  has_expiry tinyint(1) NOT NULL DEFAULT 0,
  sort_order int NOT NULL DEFAULT 0,
  deleted tinyint(1) NOT NULL DEFAULT 0,
  code_key varchar(30) GENERATED ALWAYS AS (IF(deleted = 0, code, NULL)) STORED,
  created_at datetime(6) NOT NULL,
  updated_at datetime(6) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_document_type_code (company_id, code_key),
  CONSTRAINT fk_document_type_company FOREIGN KEY (company_id) REFERENCES companies (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tài liệu của nhân viên. status: PENDING = NV tự gửi, chờ HR duyệt; APPROVED; REJECTED.
CREATE TABLE employee_documents (
  id bigint NOT NULL AUTO_INCREMENT,
  company_id bigint NOT NULL,
  employee_id bigint NOT NULL,
  document_type_id bigint NOT NULL,
  title varchar(200) DEFAULT NULL,
  file_key varchar(300) NOT NULL,
  file_name varchar(255) NOT NULL,
  content_type varchar(100) NOT NULL,
  file_size bigint NOT NULL,
  issued_on date DEFAULT NULL,
  expires_on date DEFAULT NULL,
  contract_id bigint DEFAULT NULL,
  status enum('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'APPROVED',
  review_note varchar(500) DEFAULT NULL,
  reviewed_by bigint DEFAULT NULL,
  reviewed_at datetime(6) DEFAULT NULL,
  note varchar(500) DEFAULT NULL,
  uploaded_by bigint DEFAULT NULL,
  deleted tinyint(1) NOT NULL DEFAULT 0,
  created_at datetime(6) NOT NULL,
  updated_at datetime(6) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_employee_document_employee (employee_id, deleted),
  KEY idx_employee_document_company (company_id, deleted, status),
  KEY idx_employee_document_expiry (company_id, expires_on),
  CONSTRAINT fk_employee_document_employee FOREIGN KEY (employee_id) REFERENCES employees (id),
  CONSTRAINT fk_employee_document_type FOREIGN KEY (document_type_id) REFERENCES document_types (id),
  CONSTRAINT fk_employee_document_contract FOREIGN KEY (contract_id) REFERENCES labor_contracts (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Danh mục mặc định cho các công ty hiện có (công ty mới tạo do DocumentService cấp cùng bộ này)
INSERT INTO document_types (company_id, code, name, required, has_expiry, sort_order, created_at, updated_at)
SELECT c.id, t.code, t.name, t.required, t.has_expiry, t.sort_order, NOW(6), NOW(6)
FROM companies c
CROSS JOIN (
  SELECT 'CCCD' AS code, 'Căn cước công dân (2 mặt)' AS name, 1 AS required, 1 AS has_expiry, 1 AS sort_order
  UNION ALL SELECT 'SYLL', 'Sơ yếu lý lịch', 1, 0, 2
  UNION ALL SELECT 'BANG_CAP', 'Bằng cấp', 0, 0, 3
  UNION ALL SELECT 'CHUNG_CHI', 'Chứng chỉ', 0, 1, 4
  UNION ALL SELECT 'HD_DA_KY', 'Hợp đồng / phụ lục đã ký', 0, 0, 5
  UNION ALL SELECT 'KHAM_SK', 'Giấy khám sức khoẻ', 0, 1, 6
) t;

INSERT INTO permissions (code, description, module, required_rule) VALUES
('EMPLOYEE_DOCUMENT_VIEW', 'Xem tài liệu nhân sự của nhân viên', 'EMPLOYEE', 'EMPLOYEE_VIEW'),
('EMPLOYEE_DOCUMENT_EDIT', 'Tải lên / sửa / xoá / duyệt tài liệu nhân sự, cấu hình loại tài liệu', 'EMPLOYEE', 'EMPLOYEE_DOCUMENT_VIEW');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code IN ('EMPLOYEE_DOCUMENT_VIEW', 'EMPLOYEE_DOCUMENT_EDIT')
WHERE r.name = 'Admin' AND r.deleted = 0;
