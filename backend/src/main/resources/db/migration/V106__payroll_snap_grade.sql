ALTER TABLE payrolls
    ADD COLUMN salary_grade_id BIGINT NULL,
    ADD COLUMN salary_grade_code VARCHAR(50) NULL,
    ADD COLUMN salary_grade_name VARCHAR(255) NULL,
    ADD CONSTRAINT fk_payroll_salary_grade FOREIGN KEY (salary_grade_id) REFERENCES salary_grades(id) ON DELETE SET NULL;
