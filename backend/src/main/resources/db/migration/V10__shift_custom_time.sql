ALTER TABLE shift_assignments
    ADD COLUMN custom_start_time TIME DEFAULT NULL AFTER note,
    ADD COLUMN custom_end_time   TIME DEFAULT NULL AFTER custom_start_time,
    MODIFY COLUMN shift_id BIGINT NULL;
