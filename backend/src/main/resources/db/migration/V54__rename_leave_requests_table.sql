SET @has_old := (
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = DATABASE()
    AND table_name = 'leave_requests_v2'
);

SET @has_new := (
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = DATABASE()
    AND table_name = 'leave_requests'
);

SET @sql := IF(@has_old = 1 AND @has_new = 0,
  'RENAME TABLE leave_requests_v2 TO leave_requests',
  'SELECT 1');

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
