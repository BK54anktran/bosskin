SET @column_exists := (
    SELECT COUNT(1)
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'attendance_requests'
      AND column_name = 'requested_overtime_period'
);

SET @sql := IF(
    @column_exists = 0,
    'ALTER TABLE attendance_requests ADD COLUMN requested_overtime_period VARCHAR(20) NULL AFTER requested_overtime_scope',
    'SELECT 1'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
