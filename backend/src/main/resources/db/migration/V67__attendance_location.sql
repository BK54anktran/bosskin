ALTER TABLE attendances
    ADD COLUMN check_in_latitude  DOUBLE NULL,
    ADD COLUMN check_in_longitude DOUBLE NULL,
    ADD COLUMN check_out_latitude  DOUBLE NULL,
    ADD COLUMN check_out_longitude DOUBLE NULL;
