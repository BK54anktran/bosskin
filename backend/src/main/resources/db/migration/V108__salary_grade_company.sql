-- Gắn salary_grades với company (grades không thuộc phòng ban cụ thể)
ALTER TABLE salary_grades
    ADD COLUMN company_id BIGINT NULL AFTER department_id,
    ADD CONSTRAINT fk_salary_grade_company FOREIGN KEY (company_id) REFERENCES companies(id);

-- Backfill: grades đang được employee dùng → lấy company_id từ employee
UPDATE salary_grades sg
    JOIN (
        SELECT e.salary_grade_id, e.company_id
        FROM employees e
        WHERE e.salary_grade_id IS NOT NULL
        GROUP BY e.salary_grade_id, e.company_id
    ) emp ON emp.salary_grade_id = sg.id
SET sg.company_id = emp.company_id
WHERE sg.department_id IS NULL AND sg.company_id IS NULL;

-- Grades gắn phòng ban → lấy company_id từ department
UPDATE salary_grades sg
    JOIN departments d ON sg.department_id = d.id
SET sg.company_id = d.company_id
WHERE sg.department_id IS NOT NULL AND sg.company_id IS NULL;
