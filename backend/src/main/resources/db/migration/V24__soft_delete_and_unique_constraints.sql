-- Soft delete flags for core master data
-- Safe to run after a partial failure on databases that already have some of the columns/indexes.

-- departments.deleted
SET @col_exists := (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'departments'
      AND column_name = 'deleted'
);
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE departments ADD COLUMN deleted BOOLEAN NOT NULL DEFAULT FALSE AFTER level',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'departments'
      AND index_name = 'code'
);
SET @sql := IF(@idx_exists > 0,
    'ALTER TABLE departments DROP INDEX code',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'departments'
      AND index_name = 'uk_department_company_code_deleted'
);
SET @sql := IF(@idx_exists = 0,
    'ALTER TABLE departments ADD UNIQUE KEY uk_department_company_code_deleted (company_id, code, deleted)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- positions.deleted
SET @col_exists := (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'positions'
      AND column_name = 'deleted'
);
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE positions ADD COLUMN deleted BOOLEAN NOT NULL DEFAULT FALSE AFTER updated_at',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'positions'
      AND index_name = 'code'
);
SET @sql := IF(@idx_exists > 0,
    'ALTER TABLE positions DROP INDEX code',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'positions'
      AND index_name = 'uk_position_code_deleted'
);
SET @sql := IF(@idx_exists = 0,
    'ALTER TABLE positions ADD UNIQUE KEY uk_position_code_deleted (code, deleted)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- roles.deleted
SET @col_exists := (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'roles'
      AND column_name = 'deleted'
);
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE roles ADD COLUMN deleted BOOLEAN NOT NULL DEFAULT FALSE AFTER is_default',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add replacement index before dropping uq_role_name (MySQL requires a replacement when FK uses this index)
SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'roles'
      AND index_name = 'idx_role_company_name'
);
SET @sql := IF(@idx_exists = 0,
    'ALTER TABLE roles ADD INDEX idx_role_company_name (company_id, name)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'roles'
      AND index_name = 'uq_role_name'
);
SET @sql := IF(@idx_exists > 0,
    'ALTER TABLE roles DROP INDEX uq_role_name',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'roles'
      AND index_name = 'uq_role_company_name_deleted'
);
SET @sql := IF(@idx_exists = 0,
    'ALTER TABLE roles ADD UNIQUE KEY uq_role_company_name_deleted (company_id, name, deleted)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- shift_assignments.deleted
SET @col_exists := (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'shift_assignments'
      AND column_name = 'deleted'
);
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE shift_assignments ADD COLUMN deleted BOOLEAN NOT NULL DEFAULT FALSE AFTER created_at',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'shift_assignments'
      AND index_name = 'uk_emp_date'
);
SET @sql := IF(@idx_exists > 0,
    'ALTER TABLE shift_assignments DROP INDEX uk_emp_date',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'shift_assignments'
      AND index_name = 'uk_emp_date_deleted'
);
SET @sql := IF(@idx_exists = 0,
    'ALTER TABLE shift_assignments ADD UNIQUE KEY uk_emp_date_deleted (employee_id, work_date, deleted)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- work_shifts.active uniqueness
SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'work_shifts'
      AND index_name = 'uk_company_code'
);
SET @sql := IF(@idx_exists > 0,
    'ALTER TABLE work_shifts DROP INDEX uk_company_code',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'work_shifts'
      AND index_name = 'uk_company_code_active'
);
SET @sql := IF(@idx_exists = 0,
    'ALTER TABLE work_shifts ADD UNIQUE KEY uk_company_code_active (company_id, code, active)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
