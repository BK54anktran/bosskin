ALTER TABLE attendance_requests
    ADD COLUMN requested_overtime_scope VARCHAR(20) NULL AFTER requested_overtime_minutes;
