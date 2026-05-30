-- Add role view scope columns
SET @col_exists := (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'roles'
      AND column_name = 'role_view_all_company'
);
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE roles ADD COLUMN role_view_all_company BOOLEAN NOT NULL DEFAULT TRUE AFTER is_default',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @col_exists := (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'roles'
      AND column_name = 'role_view_department_id'
);
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE roles ADD COLUMN role_view_department_id BIGINT NULL AFTER role_view_all_company',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @fk_exists := (
    SELECT COUNT(*)
    FROM information_schema.table_constraints
    WHERE table_schema = DATABASE()
      AND table_name = 'roles'
      AND constraint_name = 'fk_role_view_department'
      AND constraint_type = 'FOREIGN KEY'
);
SET @sql := IF(@fk_exists = 0,
    'ALTER TABLE roles ADD CONSTRAINT fk_role_view_department FOREIGN KEY (role_view_department_id) REFERENCES departments(id) ON DELETE SET NULL',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'roles'
      AND index_name = 'idx_role_view_department'
);
SET @sql := IF(@idx_exists = 0,
    'ALTER TABLE roles ADD INDEX idx_role_view_department (role_view_department_id)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
