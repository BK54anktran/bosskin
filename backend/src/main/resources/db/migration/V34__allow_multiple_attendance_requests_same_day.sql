-- =============================================
-- V34: Allow multiple attendance requests on the same day
-- NOTE: This migration intentionally keeps legacy `active_key`
-- and only ensures the schema no longer enforces uniqueness by
-- request date/type. Existing data is left untouched.
-- =============================================

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

SET @scope_idx_exists := (
    SELECT COUNT(1)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'attendance_requests'
      AND index_name = 'uq_attendance_request_employee_date_type_scope_period_active'
);

SET @sql := IF(
    @scope_idx_exists > 0,
    'ALTER TABLE attendance_requests DROP INDEX uq_attendance_request_employee_date_type_scope_period_active',
    'SELECT 1'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
