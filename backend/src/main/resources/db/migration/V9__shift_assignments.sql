CREATE TABLE shift_assignments (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    employee_id     BIGINT       NOT NULL,
    shift_id        BIGINT       NOT NULL,
    work_date       DATE         NOT NULL,
    note            VARCHAR(255),
    created_by      BIGINT,
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_emp_date (employee_id, work_date),
    KEY idx_assign_employee (employee_id),
    KEY idx_assign_date     (work_date),
    CONSTRAINT fk_assign_employee FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
    CONSTRAINT fk_assign_shift    FOREIGN KEY (shift_id)    REFERENCES work_shifts(id)
);
