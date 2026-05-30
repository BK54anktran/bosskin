-- Allow multiple shift assignments per employee/day while keeping soft delete.
-- The previous unique key on (employee_id, work_date, deleted) prevented more
-- than one active assignment per day, which broke valid multi-shift schedules.

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'shift_assignments'
      AND index_name = 'uk_emp_date_deleted'
);

SET @sql := IF(@idx_exists > 0,
    'ALTER TABLE shift_assignments DROP INDEX uk_emp_date_deleted',
    'SELECT 1');

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
