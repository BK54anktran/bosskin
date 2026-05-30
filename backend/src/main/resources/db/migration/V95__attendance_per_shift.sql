-- Step 1: Drop old unique constraint first
ALTER TABLE attendances DROP INDEX uq_attendance;

-- Step 2: Add shift_assignment_id column
ALTER TABLE attendances
    ADD COLUMN shift_assignment_id BIGINT NULL AFTER employee_id,
    ADD CONSTRAINT fk_attendance_shift_assignment
        FOREIGN KEY (shift_assignment_id) REFERENCES shift_assignments(id) ON DELETE SET NULL;

-- Step 3: Migrate check_in_2/check_out_2 data into separate rows (now safe, no unique constraint)
INSERT INTO attendances (employee_id, shift_assignment_id, date, check_in, check_out, status,
                         note, created_at, updated_at, approved, approved_at, approved_by_id,
                         snap_actual_hours, snap_day_hours, snap_day_ot, snap_night_hours, snap_night_ot,
                         check_in_latitude, check_in_longitude, check_out_latitude, check_out_longitude, work_flags)
SELECT employee_id, NULL, date, check_in_2, check_out_2, status,
       note, created_at, updated_at, 0, NULL, NULL,
       NULL, NULL, NULL, NULL, NULL,
       NULL, NULL, NULL, NULL, NULL
FROM attendances
WHERE check_in_2 IS NOT NULL OR check_out_2 IS NOT NULL;

-- Step 4: Drop old slot columns
ALTER TABLE attendances
    DROP COLUMN check_in_2,
    DROP COLUMN check_out_2,
    DROP COLUMN working_hours,
    DROP COLUMN overtime_hours;

-- Step 5: Add new unique constraint
ALTER TABLE attendances
    ADD CONSTRAINT uq_attendance_slot UNIQUE (employee_id, date, shift_assignment_id);
