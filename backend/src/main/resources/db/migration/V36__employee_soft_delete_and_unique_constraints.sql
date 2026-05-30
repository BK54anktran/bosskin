-- employees.deleted
SET @col_exists := (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'employees'
      AND column_name = 'deleted'
);
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE employees ADD COLUMN deleted BOOLEAN NOT NULL DEFAULT FALSE AFTER bank_name',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Drop old single-column unique keys if present
SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'employees'
      AND index_name = 'employee_code'
);
SET @sql := IF(@idx_exists > 0,
    'ALTER TABLE employees DROP INDEX employee_code',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'employees'
      AND index_name = 'email'
);
SET @sql := IF(@idx_exists > 0,
    'ALTER TABLE employees DROP INDEX email',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add soft-delete-aware unique keys
SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'employees'
      AND index_name = 'uq_employee_company_code_deleted'
);
SET @sql := IF(@idx_exists = 0,
    'ALTER TABLE employees ADD UNIQUE KEY uq_employee_company_code_deleted (company_id, employee_code, deleted)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'employees'
      AND index_name = 'uq_employee_company_email_deleted'
);
SET @sql := IF(@idx_exists = 0,
    'ALTER TABLE employees ADD UNIQUE KEY uq_employee_company_email_deleted (company_id, email, deleted)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
