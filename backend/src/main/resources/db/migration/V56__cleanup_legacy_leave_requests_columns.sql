SET @has_fk_leave_approver := (
  SELECT COUNT(*)
  FROM information_schema.table_constraints
  WHERE table_schema = DATABASE()
    AND table_name = 'leave_requests'
    AND constraint_name = 'fk_leave_approver'
    AND constraint_type = 'FOREIGN KEY'
);
SET @sql := IF(@has_fk_leave_approver > 0,
  'ALTER TABLE leave_requests DROP FOREIGN KEY fk_leave_approver',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_fk_leave_employee := (
  SELECT COUNT(*)
  FROM information_schema.table_constraints
  WHERE table_schema = DATABASE()
    AND table_name = 'leave_requests'
    AND constraint_name = 'fk_leave_employee'
    AND constraint_type = 'FOREIGN KEY'
);
SET @sql := IF(@has_fk_leave_employee > 0,
  'ALTER TABLE leave_requests DROP FOREIGN KEY fk_leave_employee',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_col_approved_by := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'leave_requests' AND column_name = 'approved_by'
);
SET @sql := IF(@has_col_approved_by > 0,
  'ALTER TABLE leave_requests DROP COLUMN approved_by',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_col_type := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'leave_requests' AND column_name = 'type'
);
SET @sql := IF(@has_col_type > 0,
  'ALTER TABLE leave_requests DROP COLUMN type',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_col_start_date := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'leave_requests' AND column_name = 'start_date'
);
SET @sql := IF(@has_col_start_date > 0,
  'ALTER TABLE leave_requests DROP COLUMN start_date',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_col_end_date := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'leave_requests' AND column_name = 'end_date'
);
SET @sql := IF(@has_col_end_date > 0,
  'ALTER TABLE leave_requests DROP COLUMN end_date',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_col_days := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'leave_requests' AND column_name = 'days'
);
SET @sql := IF(@has_col_days > 0,
  'ALTER TABLE leave_requests DROP COLUMN days',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_col_note := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'leave_requests' AND column_name = 'note'
);
SET @sql := IF(@has_col_note > 0,
  'ALTER TABLE leave_requests DROP COLUMN note',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_idx_company := (
  SELECT COUNT(*)
  FROM information_schema.statistics
  WHERE table_schema = DATABASE()
    AND table_name = 'leave_requests'
    AND index_name = 'idx_leave_req_company'
);
SET @sql := IF(@has_idx_company = 0,
  'CREATE INDEX idx_leave_req_company ON leave_requests(company_id)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_idx_type := (
  SELECT COUNT(*)
  FROM information_schema.statistics
  WHERE table_schema = DATABASE()
    AND table_name = 'leave_requests'
    AND index_name = 'idx_leave_req_type'
);
SET @sql := IF(@has_idx_type = 0,
  'CREATE INDEX idx_leave_req_type ON leave_requests(leave_type_id)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_idx_processed_by := (
  SELECT COUNT(*)
  FROM information_schema.statistics
  WHERE table_schema = DATABASE()
    AND table_name = 'leave_requests'
    AND index_name = 'idx_leave_req_processed_by'
);
SET @sql := IF(@has_idx_processed_by = 0,
  'CREATE INDEX idx_leave_req_processed_by ON leave_requests(processed_by)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_fk_req_company := (
  SELECT COUNT(*)
  FROM information_schema.table_constraints
  WHERE table_schema = DATABASE()
    AND table_name = 'leave_requests'
    AND constraint_name = 'fk_leave_requests_company'
    AND constraint_type = 'FOREIGN KEY'
);
SET @sql := IF(@has_fk_req_company = 0,
  'ALTER TABLE leave_requests ADD CONSTRAINT fk_leave_requests_company FOREIGN KEY (company_id) REFERENCES companies(id)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_fk_req_employee := (
  SELECT COUNT(*)
  FROM information_schema.table_constraints
  WHERE table_schema = DATABASE()
    AND table_name = 'leave_requests'
    AND constraint_name = 'fk_leave_requests_employee'
    AND constraint_type = 'FOREIGN KEY'
);
SET @sql := IF(@has_fk_req_employee = 0,
  'ALTER TABLE leave_requests ADD CONSTRAINT fk_leave_requests_employee FOREIGN KEY (employee_id) REFERENCES employees(id)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_fk_req_type := (
  SELECT COUNT(*)
  FROM information_schema.table_constraints
  WHERE table_schema = DATABASE()
    AND table_name = 'leave_requests'
    AND constraint_name = 'fk_leave_requests_type'
    AND constraint_type = 'FOREIGN KEY'
);
SET @sql := IF(@has_fk_req_type = 0,
  'ALTER TABLE leave_requests ADD CONSTRAINT fk_leave_requests_type FOREIGN KEY (leave_type_id) REFERENCES leave_types(id)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_fk_req_processed_by := (
  SELECT COUNT(*)
  FROM information_schema.table_constraints
  WHERE table_schema = DATABASE()
    AND table_name = 'leave_requests'
    AND constraint_name = 'fk_leave_requests_processed_by'
    AND constraint_type = 'FOREIGN KEY'
);
SET @sql := IF(@has_fk_req_processed_by = 0,
  'ALTER TABLE leave_requests ADD CONSTRAINT fk_leave_requests_processed_by FOREIGN KEY (processed_by) REFERENCES users(id)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
