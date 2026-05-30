ALTER TABLE salary_grades
    DROP FOREIGN KEY fk_sg_position,
    DROP INDEX idx_sg_position,
    DROP INDEX uq_sg_position_code,
    DROP COLUMN position_id,
    ADD COLUMN department_id BIGINT NULL,
    ADD CONSTRAINT fk_sg_department FOREIGN KEY (department_id) REFERENCES departments (id),
    ADD UNIQUE KEY uq_sg_dept_code (department_id, code);

CREATE INDEX idx_sg_department ON salary_grades (department_id);
