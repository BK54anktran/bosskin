-- =====================================================================
-- V4 · Bảng lương: lưu người duyệt / người xác nhận đã trả (Mốc 3b, L18)
-- =====================================================================
ALTER TABLE payrolls
    ADD COLUMN approved_by_id BIGINT NULL,
    ADD COLUMN paid_by_id     BIGINT NULL,
    ADD CONSTRAINT fk_payroll_approved_by FOREIGN KEY (approved_by_id) REFERENCES users (id) ON DELETE SET NULL,
    ADD CONSTRAINT fk_payroll_paid_by     FOREIGN KEY (paid_by_id)     REFERENCES users (id) ON DELETE SET NULL;
