ALTER TABLE leave_accrual_rules
    ADD COLUMN grant_unit VARCHAR(10) NOT NULL DEFAULT 'DAY';
