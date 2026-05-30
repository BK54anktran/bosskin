SET @idx_exists := (
    SELECT COUNT(1)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'attendance_requests'
      AND index_name = 'uq_attendance_request_employee_date_type'
);

SET @employee_idx_exists := (
    SELECT COUNT(1)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'attendance_requests'
      AND index_name = 'idx_attendance_request_employee_id'
);

SET @sql := IF(
    @employee_idx_exists = 0,
    'ALTER TABLE attendance_requests ADD INDEX idx_attendance_request_employee_id (employee_id)',
    'SELECT 1'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @idx_exists > 0,
    'ALTER TABLE attendance_requests DROP INDEX uq_attendance_request_employee_date_type',
    'SELECT 1'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists := (
    SELECT COUNT(1)
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'attendance_requests'
      AND column_name = 'active_key'
);

SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE attendance_requests
        ADD COLUMN active_key TINYINT
            GENERATED ALWAYS AS (
                CASE
                    WHEN status IN (''PENDING'', ''APPROVED'') THEN 1
                    ELSE NULL
                END
            ) STORED',
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
      AND index_name = 'uq_attendance_request_employee_date_type_active'
);

SET @sql := IF(
    @new_idx_exists = 0,
    'ALTER TABLE attendance_requests
        ADD UNIQUE KEY uq_attendance_request_employee_date_type_active
            (employee_id, request_date, request_type, active_key)',
    'SELECT 1'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
