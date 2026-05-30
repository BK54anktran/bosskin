CREATE TABLE salary_histories (
    id             BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id    BIGINT         NOT NULL,
    base_salary    DECIMAL(15, 2) NOT NULL,
    effective_date DATE           NOT NULL,
    note           TEXT,
    created_at     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_salary_history_employee FOREIGN KEY (employee_id) REFERENCES employees (id)
);

CREATE INDEX idx_salary_history_employee_date ON salary_histories (employee_id, effective_date DESC);
