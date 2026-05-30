-- LeaveAccrualRule: replace grant_amount + grant_unit with 2 independent columns
ALTER TABLE leave_accrual_rules
    DROP COLUMN grant_unit,
    DROP COLUMN grant_amount,
    ADD COLUMN grant_days  DECIMAL(10, 2) NULL,
    ADD COLUMN grant_hours DECIMAL(10, 2) NULL;

-- LeaveGrant: store original input alongside canonical amount
ALTER TABLE leave_grants
    ADD COLUMN grant_days  DECIMAL(10, 2) NULL,
    ADD COLUMN grant_hours DECIMAL(10, 2) NULL;
