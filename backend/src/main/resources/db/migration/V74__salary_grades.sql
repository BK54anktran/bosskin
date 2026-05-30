CREATE TABLE salary_grades (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    position_id BIGINT          NOT NULL,
    code        VARCHAR(20)     NOT NULL,
    name        VARCHAR(100)    NOT NULL,
    pay_type    ENUM('DAILY','HOURLY') NOT NULL DEFAULT 'DAILY',
    base_rate   DECIMAL(15, 2)  NOT NULL,
    created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_sg_position FOREIGN KEY (position_id) REFERENCES positions (id),
    UNIQUE KEY uq_sg_position_code (position_id, code)
);

CREATE INDEX idx_sg_position ON salary_grades (position_id);

ALTER TABLE employees
    ADD COLUMN salary_grade_id BIGINT NULL,
    ADD CONSTRAINT fk_emp_salary_grade FOREIGN KEY (salary_grade_id) REFERENCES salary_grades (id);
