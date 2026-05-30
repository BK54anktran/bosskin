SET @idx_exists := (
    SELECT COUNT(1)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'attendance_requests'
      AND index_name = 'uq_attendance_request_employee_date_type_active'
);

SET @sql := IF(
    @idx_exists > 0,
    'ALTER TABLE attendance_requests DROP INDEX uq_attendance_request_employee_date_type_active',
    'SELECT 1'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @new_idx_exists := (
    SELECT COUNT(1)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'attendance_requests'
      AND index_name = 'uq_attendance_request_employee_date_type_scope_period_active'
);

SET @sql := IF(
    @new_idx_exists = 0,
    'ALTER TABLE attendance_requests
        ADD UNIQUE KEY uq_attendance_request_employee_date_type_scope_period_active
            (employee_id, request_date, request_type, requested_overtime_scope, requested_overtime_period, active_key)',
    'SELECT 1'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
