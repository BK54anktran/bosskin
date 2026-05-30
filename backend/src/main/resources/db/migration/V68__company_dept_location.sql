ALTER TABLE companies
    ADD COLUMN check_in_latitude      DOUBLE NULL,
    ADD COLUMN check_in_longitude     DOUBLE NULL,
    ADD COLUMN check_in_radius_meters INT    NOT NULL DEFAULT 100;

ALTER TABLE departments
    ADD COLUMN check_in_latitude      DOUBLE NULL,
    ADD COLUMN check_in_longitude     DOUBLE NULL,
    ADD COLUMN check_in_radius_meters INT    NOT NULL DEFAULT 100;
