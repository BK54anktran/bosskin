ALTER TABLE leave_grants
    MODIFY COLUMN leave_type_id BIGINT NULL;

ALTER TABLE leave_accrual_rules
    MODIFY COLUMN leave_type_id BIGINT NULL;
