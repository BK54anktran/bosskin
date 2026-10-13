-- Sửa dữ liệu (13/10/2026): trước đây xoá bậc lương (nút xoá, nhập Excel) và xoá chức vụ qua nhập Excel không kiểm tra
-- còn nhân viên / quá trình công tác dùng. Bản ghi bị xoá mềm nhưng NV vẫn trỏ tới → nạp NV ném EntityNotFoundException,
-- danh sách nhân viên trả 500. Code đã chặn xoá khi còn dùng (error.salary_grade.in_use, error.position.in_use);
-- migration này gỡ các liên kết hỏng sẵn có, không xoá gì:
--   1. Khôi phục (deleted = 0) bản đã xoá còn được dùng, nếu chưa có bản đang dùng cùng khoá (mỗi khoá một bản, id lớn nhất).
--   2. Liên kết còn lại (đã có bản đang dùng cùng mã → người dùng tạo lại) trỏ sang bản đang dùng đó.
-- Bảng dẫn xuất có DISTINCT / GROUP BY để MySQL tạo bảng tạm, tránh lỗi 1093 khi UPDATE bảng có trong truy vấn con.

-- ── Bậc lương: khoá = (company_id, department_id, code) như cột sinh grade_key ──────────────────────
UPDATE salary_grades g
JOIN (
    SELECT MAX(d.id) AS id
    FROM salary_grades d
    WHERE d.deleted = 1
      AND (EXISTS (SELECT 1 FROM employees e WHERE e.salary_grade_id = d.id AND e.deleted = 0)
        OR EXISTS (SELECT 1 FROM employee_job_histories h JOIN employees e ON e.id = h.employee_id
                   WHERE h.salary_grade_id = d.id AND h.deleted = 0 AND e.deleted = 0))
      AND NOT EXISTS (SELECT 1 FROM salary_grades a
                      WHERE a.deleted = 0 AND a.company_id <=> d.company_id
                        AND IFNULL(a.department_id, 0) = IFNULL(d.department_id, 0) AND a.code = d.code)
    GROUP BY d.company_id, IFNULL(d.department_id, 0), d.code
) r ON r.id = g.id
SET g.deleted = 0;

UPDATE employees e
JOIN salary_grades d ON d.id = e.salary_grade_id AND d.deleted = 1
JOIN salary_grades a ON a.deleted = 0 AND a.company_id <=> d.company_id
                    AND IFNULL(a.department_id, 0) = IFNULL(d.department_id, 0) AND a.code = d.code
SET e.salary_grade_id = a.id;

UPDATE employee_job_histories h
JOIN salary_grades d ON d.id = h.salary_grade_id AND d.deleted = 1
JOIN salary_grades a ON a.deleted = 0 AND a.company_id <=> d.company_id
                    AND IFNULL(a.department_id, 0) = IFNULL(d.department_id, 0) AND a.code = d.code
SET h.salary_grade_id = a.id;

-- ── Chức vụ: khoá = (department_id, code) như cột sinh code_key ──────────────────────────────────
UPDATE positions p
JOIN (
    SELECT MAX(d.id) AS id
    FROM positions d
    WHERE d.deleted = 1
      AND (EXISTS (SELECT 1 FROM employees e WHERE e.position_id = d.id AND e.deleted = 0)
        OR EXISTS (SELECT 1 FROM employee_job_histories h JOIN employees e ON e.id = h.employee_id
                   WHERE h.position_id = d.id AND h.deleted = 0 AND e.deleted = 0))
      AND NOT EXISTS (SELECT 1 FROM positions a
                      WHERE a.deleted = 0 AND a.department_id = d.department_id AND a.code = d.code)
    GROUP BY d.department_id, d.code
) r ON r.id = p.id
SET p.deleted = 0;

UPDATE employees e
JOIN positions d ON d.id = e.position_id AND d.deleted = 1
JOIN positions a ON a.deleted = 0 AND a.department_id = d.department_id AND a.code = d.code
SET e.position_id = a.id;

UPDATE employee_job_histories h
JOIN positions d ON d.id = h.position_id AND d.deleted = 1
JOIN positions a ON a.deleted = 0 AND a.department_id = d.department_id AND a.code = d.code
SET h.position_id = a.id;
