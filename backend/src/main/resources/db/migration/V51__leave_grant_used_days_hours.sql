ALTER TABLE leave_grants
    DROP COLUMN used_amount,
    ADD COLUMN used_days  DECIMAL(10, 2) NOT NULL DEFAULT 0,
    ADD COLUMN used_hours DECIMAL(10, 2) NOT NULL DEFAULT 0;
