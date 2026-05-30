SET @has_fk := (
  SELECT COUNT(*)
  FROM information_schema.table_constraints
  WHERE table_schema = DATABASE()
    AND table_name = 'leave_accrual_rules'
    AND constraint_name = 'fk_leave_rule_type'
    AND constraint_type = 'FOREIGN KEY'
);
SET @sql := IF(@has_fk > 0,
  'ALTER TABLE leave_accrual_rules DROP FOREIGN KEY fk_leave_rule_type',
  'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_col := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'leave_accrual_rules'
    AND column_name = 'leave_type_id'
);
SET @sql := IF(@has_col > 0,
  'ALTER TABLE leave_accrual_rules DROP COLUMN leave_type_id',
  'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
