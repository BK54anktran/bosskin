-- =====================================================================
-- V2 · Khoá kỳ công (Mốc 2, A12)
-- Kỳ công tính theo ngày chốt công của công ty (companies.payroll_cutoff_day).
-- Kỳ đã khoá thì mọi thao tác ghi chấm công / đơn / nghỉ phép / phân ca trong
-- khoảng ngày của kỳ bị từ chối. Mở lại kỳ cần quyền ATTENDANCE_PERIOD_LOCK và lý do.
-- =====================================================================
CREATE TABLE attendance_period_locks (
  id              BIGINT       NOT NULL AUTO_INCREMENT,
  company_id      BIGINT       NOT NULL,
  year            INT          NOT NULL,
  month           INT          NOT NULL,
  period_from     DATE         NOT NULL,
  period_to       DATE         NOT NULL,
  locked          TINYINT(1)   NOT NULL DEFAULT 1,
  locked_at       DATETIME(6)  NULL,
  locked_by_id    BIGINT       NULL,
  unlocked_at     DATETIME(6)  NULL,
  unlocked_by_id  BIGINT       NULL,
  unlock_reason   VARCHAR(500) NULL,
  created_at      DATETIME(6)  NOT NULL,
  updated_at      DATETIME(6)  NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_period_lock_company_month (company_id, year, month),
  KEY idx_period_lock_range (company_id, locked, period_from, period_to),
  CONSTRAINT fk_period_lock_company FOREIGN KEY (company_id) REFERENCES companies (id),
  CONSTRAINT fk_period_lock_locked_by FOREIGN KEY (locked_by_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_period_lock_unlocked_by FOREIGN KEY (unlocked_by_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO permissions (code, description, module, required_rule) VALUES
('ATTENDANCE_PERIOD_LOCK', 'Khoá / mở lại kỳ công', 'ATTENDANCE', 'ATTENDANCE_VIEW');

-- Vai trò Admin của các công ty đã có (tạo trước migration này) nhận quyền mới
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code = 'ATTENDANCE_PERIOD_LOCK'
WHERE r.name = 'Admin' AND r.deleted = 0;
