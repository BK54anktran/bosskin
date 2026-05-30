SET @has_company_id := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'leave_requests' AND column_name = 'company_id'
);
SET @sql := IF(@has_company_id = 0, 'ALTER TABLE leave_requests ADD COLUMN company_id BIGINT NULL', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_leave_type_id := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'leave_requests' AND column_name = 'leave_type_id'
);
SET @sql := IF(@has_leave_type_id = 0, 'ALTER TABLE leave_requests ADD COLUMN leave_type_id BIGINT NULL', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_mode := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'leave_requests' AND column_name = 'mode'
);
SET @sql := IF(@has_mode = 0, 'ALTER TABLE leave_requests ADD COLUMN mode ENUM(''DAY_RANGE'',''HOUR_RANGE'') NULL', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_from_date := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'leave_requests' AND column_name = 'from_date'
);
SET @sql := IF(@has_from_date = 0, 'ALTER TABLE leave_requests ADD COLUMN from_date DATE NULL', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_to_date := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'leave_requests' AND column_name = 'to_date'
);
SET @sql := IF(@has_to_date = 0, 'ALTER TABLE leave_requests ADD COLUMN to_date DATE NULL', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_from_time := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'leave_requests' AND column_name = 'from_time'
);
SET @sql := IF(@has_from_time = 0, 'ALTER TABLE leave_requests ADD COLUMN from_time TIME NULL', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_to_time := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'leave_requests' AND column_name = 'to_time'
);
SET @sql := IF(@has_to_time = 0, 'ALTER TABLE leave_requests ADD COLUMN to_time TIME NULL', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_requested_amount := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'leave_requests' AND column_name = 'requested_amount'
);
SET @sql := IF(@has_requested_amount = 0, 'ALTER TABLE leave_requests ADD COLUMN requested_amount DECIMAL(10,2) NULL', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_admin_note := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'leave_requests' AND column_name = 'admin_note'
);
SET @sql := IF(@has_admin_note = 0, 'ALTER TABLE leave_requests ADD COLUMN admin_note VARCHAR(500) NULL', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_processed_by := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'leave_requests' AND column_name = 'processed_by'
);
SET @sql := IF(@has_processed_by = 0, 'ALTER TABLE leave_requests ADD COLUMN processed_by BIGINT NULL', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_processed_at := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'leave_requests' AND column_name = 'processed_at'
);
SET @sql := IF(@has_processed_at = 0, 'ALTER TABLE leave_requests ADD COLUMN processed_at DATETIME(6) NULL', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

UPDATE leave_requests lr
JOIN employees e ON e.id = lr.employee_id
SET lr.company_id = e.company_id
WHERE lr.company_id IS NULL;

UPDATE leave_requests
SET from_date = COALESCE(from_date, start_date)
WHERE from_date IS NULL;

UPDATE leave_requests
SET to_date = COALESCE(to_date, end_date)
WHERE to_date IS NULL;

UPDATE leave_requests
SET requested_amount = COALESCE(requested_amount, CAST(COALESCE(days, 0) AS DECIMAL(10,2)))
WHERE requested_amount IS NULL;

UPDATE leave_requests
SET admin_note = COALESCE(admin_note, LEFT(note, 500))
WHERE admin_note IS NULL;

UPDATE leave_requests
SET processed_by = COALESCE(processed_by, approved_by)
WHERE processed_by IS NULL;

UPDATE leave_requests
SET mode = COALESCE(mode, 'DAY_RANGE')
WHERE mode IS NULL;

INSERT INTO leave_types (company_id, code, name, unit, is_paid, active, description, created_at, updated_at)
SELECT c.id, 'LEGACY', 'Legacy leave', 'DAY', TRUE, TRUE, 'Auto-created for legacy leave request migration', NOW(6), NOW(6)
FROM companies c
WHERE NOT EXISTS (
    SELECT 1
    FROM leave_types lt
    WHERE lt.company_id = c.id
);

UPDATE leave_requests lr
JOIN leave_types lt ON lt.company_id = lr.company_id
SET lr.leave_type_id = lt.id
WHERE lr.leave_type_id IS NULL;

ALTER TABLE leave_requests
    MODIFY COLUMN company_id BIGINT NOT NULL,
    MODIFY COLUMN leave_type_id BIGINT NOT NULL,
    MODIFY COLUMN mode ENUM('DAY_RANGE','HOUR_RANGE') NOT NULL,
    MODIFY COLUMN from_date DATE NOT NULL,
    MODIFY COLUMN to_date DATE NOT NULL,
    MODIFY COLUMN requested_amount DECIMAL(10,2) NOT NULL,
    MODIFY COLUMN reason VARCHAR(500) NULL,
    MODIFY COLUMN admin_note VARCHAR(500) NULL,
    MODIFY COLUMN status ENUM('PENDING','APPROVED','REJECTED','CANCELLED') NOT NULL DEFAULT 'PENDING';
