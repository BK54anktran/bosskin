-- =====================================================================
-- V5 · Ca đa năng (Mốc 2b)
--  * Ca linh hoạt: shift_type = FLEXIBLE, chỉ quy định số phút phải làm (required_minutes)
--    trong khung [start_time, end_time]; thiếu giờ = đi muộn. Snapshot vào phân ca.
--  * Mẫu ca xoay vòng (shift_rotations): chu kỳ các ngày, mỗi ngày là danh sách id ca
--    ("12+13" = 2 ca trong ngày, "0" = nghỉ), sinh phân ca cho khoảng ngày.
--  * Yêu cầu đổi ca / nhường ca (shift_swap_requests), quản lý duyệt.
-- =====================================================================
ALTER TABLE work_shifts
  ADD COLUMN shift_type       VARCHAR(20) NOT NULL DEFAULT 'FIXED',
  ADD COLUMN required_minutes INT         NULL;

ALTER TABLE shift_assignments
  ADD COLUMN snapshot_shift_type       VARCHAR(20) NULL,
  ADD COLUMN snapshot_required_minutes INT         NULL;

CREATE TABLE shift_rotations (
  id          BIGINT        NOT NULL AUTO_INCREMENT,
  company_id  BIGINT        NOT NULL,
  name        VARCHAR(100)  NOT NULL,
  pattern     VARCHAR(2000) NOT NULL,
  active      TINYINT(1)    NOT NULL DEFAULT 1,
  created_at  DATETIME(6)   NOT NULL,
  updated_at  DATETIME(6)   NOT NULL,
  PRIMARY KEY (id),
  KEY idx_rotation_company (company_id, active),
  CONSTRAINT fk_rotation_company FOREIGN KEY (company_id) REFERENCES companies (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE shift_swap_requests (
  id                      BIGINT       NOT NULL AUTO_INCREMENT,
  company_id              BIGINT       NOT NULL,
  requester_id            BIGINT       NOT NULL,
  requester_assignment_id BIGINT       NOT NULL,
  target_employee_id      BIGINT       NOT NULL,
  target_assignment_id    BIGINT       NULL,
  reason                  VARCHAR(500) NULL,
  status                  VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
  processed_by_id         BIGINT       NULL,
  processed_at            DATETIME(6)  NULL,
  admin_note              VARCHAR(500) NULL,
  created_at              DATETIME(6)  NOT NULL,
  updated_at              DATETIME(6)  NOT NULL,
  PRIMARY KEY (id),
  KEY idx_swap_company_status (company_id, status),
  KEY idx_swap_requester (requester_id),
  KEY idx_swap_target (target_employee_id),
  CONSTRAINT fk_swap_company FOREIGN KEY (company_id) REFERENCES companies (id),
  CONSTRAINT fk_swap_requester FOREIGN KEY (requester_id) REFERENCES employees (id),
  CONSTRAINT fk_swap_req_assign FOREIGN KEY (requester_assignment_id) REFERENCES shift_assignments (id),
  CONSTRAINT fk_swap_target FOREIGN KEY (target_employee_id) REFERENCES employees (id),
  CONSTRAINT fk_swap_target_assign FOREIGN KEY (target_assignment_id) REFERENCES shift_assignments (id),
  CONSTRAINT fk_swap_processed_by FOREIGN KEY (processed_by_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO permissions (code, description, module, required_rule) VALUES
('SHIFT_SWAP_APPROVE', 'Duyệt yêu cầu đổi ca / nhường ca', 'SHIFT', 'SHIFT_VIEW');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code = 'SHIFT_SWAP_APPROVE'
WHERE r.name = 'Admin' AND r.deleted = 0;
