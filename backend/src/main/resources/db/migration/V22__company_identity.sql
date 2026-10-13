-- V22: định danh theo công ty
--  * Đuôi email (companies.domain) chuẩn hoá chữ thường, bỏ "@" đầu, không trùng giữa các công ty.
--    Công ty trùng đuôi: giữ ở công ty tạo trước, công ty sau để trống (system admin đặt lại ở /admin).
--  * Mã NV cấp tự động "EMP00001" đổi thành <mã công ty> + số: "THCO00001" (CompanyIdentity / EmployeeCodeService).
--    Bỏ qua dòng mà mã mới đã có người dùng hoặc dài quá 20 ký tự. Bộ đếm employee_code_counters giữ nguyên (cùng số).

UPDATE companies SET domain = NULL WHERE domain IS NOT NULL AND TRIM(domain) = '';
UPDATE companies SET domain = LOWER(TRIM(LEADING '@' FROM TRIM(domain))) WHERE domain IS NOT NULL;

UPDATE companies c
JOIN (SELECT domain, MIN(id) AS keep_id FROM companies WHERE domain IS NOT NULL GROUP BY domain HAVING COUNT(*) > 1) d
  ON c.domain = d.domain AND c.id <> d.keep_id
SET c.domain = NULL;

ALTER TABLE companies ADD UNIQUE KEY uq_company_domain (domain);

UPDATE employees e
JOIN companies c ON c.id = e.company_id
LEFT JOIN employees x ON x.company_id = e.company_id
                     AND x.employee_code = CONVERT(CONCAT(c.code, SUBSTRING(e.employee_code, 4)) USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
SET e.employee_code = CONCAT(c.code, SUBSTRING(e.employee_code, 4))
WHERE e.employee_code REGEXP '^EMP[0-9]+$'
  AND c.code <> 'EMP'
  AND x.id IS NULL
  AND CHAR_LENGTH(CONCAT(c.code, SUBSTRING(e.employee_code, 4))) <= 20;
