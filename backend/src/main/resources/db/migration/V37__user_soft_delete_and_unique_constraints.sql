-- users.deleted
SET @col_exists := (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'users'
      AND column_name = 'deleted'
);
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE users ADD COLUMN deleted BOOLEAN NOT NULL DEFAULT FALSE AFTER enabled',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Drop old unique key on email if present
SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'users'
      AND index_name = 'email'
);
SET @sql := IF(@idx_exists > 0,
    'ALTER TABLE users DROP INDEX email',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add soft-delete-aware unique key
SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'users'
      AND index_name = 'uq_user_email_deleted'
);
SET @sql := IF(@idx_exists = 0,
    'ALTER TABLE users ADD UNIQUE KEY uq_user_email_deleted (email, deleted)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
