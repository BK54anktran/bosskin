ALTER TABLE leave_accrual_rules
    ADD COLUMN department_id BIGINT NULL AFTER leave_type_id;

ALTER TABLE leave_accrual_rules
    ADD CONSTRAINT fk_leave_rule_department
    FOREIGN KEY (department_id) REFERENCES departments(id);

CREATE INDEX idx_leave_rule_department_id ON leave_accrual_rules(department_id);
