ALTER TABLE shift_assignments
    ADD COLUMN custom_break_start TIME DEFAULT NULL AFTER custom_end_time,
    ADD COLUMN custom_break_end   TIME DEFAULT NULL AFTER custom_break_start;
