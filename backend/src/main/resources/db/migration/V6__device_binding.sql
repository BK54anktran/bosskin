-- =====================================================================
-- V6 · Gắn thiết bị chấm công (Mốc 2, còn lại)
-- Công ty bật device_binding_enabled: nhân viên chỉ tự chấm công được trên thiết bị đã gắn.
-- Lần chấm đầu tiên tự gắn thiết bị đang dùng; quản lý gỡ khi nhân viên đổi máy.
-- =====================================================================
ALTER TABLE companies
  ADD COLUMN device_binding_enabled TINYINT(1) NOT NULL DEFAULT 0;

ALTER TABLE employees
  ADD COLUMN bound_device_id VARCHAR(255) NULL,
  ADD COLUMN bound_device_at DATETIME(6)  NULL;
