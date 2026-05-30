-- =============================================
-- V35: Support two attendance slots per day and request shift mapping
-- =============================================

SET @col_exists := (
    SELECT COUNT(1)
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'attendances'
      AND column_name = 'check_in_2'
);

SET @sql := IF(
    @col_exists = 0,
    'ALTER TABLE attendances ADD COLUMN check_in_2 DATETIME NULL AFTER check_out',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @col_exists := (
    SELECT COUNT(1)
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'attendances'
      AND column_name = 'check_out_2'
);

SET @sql := IF(
    @col_exists = 0,
    'ALTER TABLE attendances ADD COLUMN check_out_2 DATETIME NULL AFTER check_in_2',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @col_exists := (
    SELECT COUNT(1)
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'attendance_requests'
      AND column_name = 'shift_assignment_id'
);

SET @sql := IF(
    @col_exists = 0,
    'ALTER TABLE attendance_requests ADD COLUMN shift_assignment_id BIGINT NULL AFTER employee_id',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(1)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'attendance_requests'
      AND index_name = 'idx_attendance_request_shift_assignment_id'
);

SET @sql := IF(
    @idx_exists = 0,
    'ALTER TABLE attendance_requests ADD INDEX idx_attendance_request_shift_assignment_id (shift_assignment_id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @fk_exists := (
    SELECT COUNT(1)
    FROM information_schema.table_constraints
    WHERE table_schema = DATABASE()
      AND table_name = 'attendance_requests'
      AND constraint_name = 'fk_attendance_requests_shift_assignment'
);

SET @sql := IF(
    @fk_exists = 0,
    'ALTER TABLE attendance_requests
        ADD CONSTRAINT fk_attendance_requests_shift_assignment
        FOREIGN KEY (shift_assignment_id) REFERENCES shift_assignments(id)
        ON DELETE SET NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Backfill legacy requests to the earliest shift of the day when possible.
UPDATE attendance_requests ar
JOIN (
    SELECT request_id, shift_assignment_id
    FROM (
        SELECT
            ar2.id AS request_id,
            sa.id AS shift_assignment_id,
            ROW_NUMBER() OVER (
                PARTITION BY ar2.id
                ORDER BY
                    COALESCE(sa.custom_start_time, ws.start_time),
                    sa.id
            ) AS rn
        FROM attendance_requests ar2
        JOIN shift_assignments sa
          ON sa.employee_id = ar2.employee_id
         AND sa.work_date = ar2.request_date
         AND sa.deleted = FALSE
        LEFT JOIN work_shifts ws
          ON ws.id = sa.shift_id
        WHERE ar2.shift_assignment_id IS NULL
    ) ranked
    WHERE ranked.rn = 1
) picked ON picked.request_id = ar.id
SET ar.shift_assignment_id = picked.shift_assignment_id
WHERE ar.shift_assignment_id IS NULL;
