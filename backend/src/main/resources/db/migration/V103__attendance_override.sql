ALTER TABLE attendances
    ADD COLUMN override_check_in      TIME          NULL,
    ADD COLUMN override_check_out     TIME          NULL,
    ADD COLUMN override_break_minutes INT           NULL,
    ADD COLUMN override_ot_day_minutes   INT        NULL,
    ADD COLUMN override_ot_night_minutes INT        NULL,
    ADD COLUMN override_note          VARCHAR(255)  NULL;
