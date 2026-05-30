ALTER TABLE companies
    ADD COLUMN leave_hours_per_day DECIMAL(10,2) NOT NULL DEFAULT 8.00 AFTER self_attendance_enabled;
