ALTER TABLE leave_types
    ADD COLUMN deduct_per_day DECIMAL(10,2) NOT NULL DEFAULT 1.00 AFTER unit;
