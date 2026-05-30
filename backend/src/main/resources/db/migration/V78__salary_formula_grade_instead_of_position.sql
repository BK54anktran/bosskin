ALTER TABLE salary_formulas
    DROP FOREIGN KEY fk_sf_position,
    DROP INDEX idx_sf_position_date,
    DROP COLUMN position_id,
    ADD COLUMN salary_grade_id BIGINT NOT NULL,
    ADD CONSTRAINT fk_sf_grade FOREIGN KEY (salary_grade_id) REFERENCES salary_grades (id);

CREATE INDEX idx_sf_grade_date ON salary_formulas (salary_grade_id, effective_date DESC);
