-- Dọn các mục còn mở trong trang Đánh giá (10/10/2026).

-- D6: mã nhân viên trước đây = số NV + 1 → trùng sau khi xoá, tranh chấp khi tạo đồng thời.
-- Bộ đếm riêng từng công ty; EmployeeCodeService khoá dòng (SELECT … FOR UPDATE) khi cấp mã.
CREATE TABLE employee_code_counters (
  company_id bigint NOT NULL,
  last_seq int NOT NULL,
  PRIMARY KEY (company_id),
  CONSTRAINT fk_employee_code_counter_company FOREIGN KEY (company_id) REFERENCES companies (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Khởi tạo từ mã lớn nhất đã dùng (kể cả NV đã xoá) để không cấp lại mã cũ
INSERT INTO employee_code_counters (company_id, last_seq)
SELECT c.id,
       COALESCE((SELECT MAX(CAST(SUBSTRING(e.employee_code, 4) AS UNSIGNED))
                 FROM employees e
                 WHERE e.company_id = c.id AND e.employee_code REGEXP '^EMP[0-9]+$'), 0)
FROM companies c;

-- D11: yêu cầu sửa hồ sơ lưu giá trị cũ lúc duyệt (trước đây chỉ còn giá trị mới)
ALTER TABLE profile_edit_requests
  ADD COLUMN old_full_name varchar(100) NULL,
  ADD COLUMN old_gender enum('MALE','FEMALE','OTHER') NULL,
  ADD COLUMN old_date_of_birth date NULL,
  ADD COLUMN old_phone varchar(15) NULL,
  ADD COLUMN old_personal_email varchar(100) NULL,
  ADD COLUMN processed_at datetime(6) NULL;
