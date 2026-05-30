ALTER TABLE salary_formulas
    ADD COLUMN name VARCHAR(100) NULL AFTER salary_grade_id;

-- Gán tên tạm thời cho các bản ghi cũ dựa trên salary_grade
UPDATE salary_formulas sf
JOIN salary_grades sg ON sf.salary_grade_id = sg.id
SET sf.name = CONCAT(sg.code, ' — ', sg.name)
WHERE sf.name IS NULL;

ALTER TABLE salary_formulas
    MODIFY COLUMN name VARCHAR(100) NOT NULL;
