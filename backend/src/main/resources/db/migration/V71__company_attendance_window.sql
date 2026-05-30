ALTER TABLE companies
    ADD COLUMN check_in_before_minutes  INT NOT NULL DEFAULT 30,
    ADD COLUMN check_in_after_minutes   INT NOT NULL DEFAULT 30,
    ADD COLUMN check_out_before_minutes INT NOT NULL DEFAULT 30,
    ADD COLUMN check_out_after_minutes  INT NOT NULL DEFAULT 30;
