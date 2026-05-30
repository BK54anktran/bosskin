ALTER TABLE payrolls
    ADD COLUMN day_hours   DECIMAL(8,2) NULL,
    ADD COLUMN night_hours DECIMAL(8,2) NULL,
    ADD COLUMN day_ot      DECIMAL(8,2) NULL,
    ADD COLUMN night_ot    DECIMAL(8,2) NULL;
