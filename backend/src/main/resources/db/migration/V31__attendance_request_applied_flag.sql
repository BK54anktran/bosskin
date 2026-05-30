SET @applied_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'attendance_requests'
      AND COLUMN_NAME = 'applied'
);
SET @sql := IF(
    @applied_exists = 0,
    'ALTER TABLE attendance_requests ADD COLUMN applied TINYINT(1) NOT NULL DEFAULT 1 AFTER requested_overtime_period',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
