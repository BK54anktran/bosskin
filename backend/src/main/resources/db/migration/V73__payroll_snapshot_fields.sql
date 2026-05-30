ALTER TABLE payrolls
    ADD COLUMN present_days          INT            NULL,
    ADD COLUMN total_overtime_hours  DECIMAL(8, 2)  NULL;
