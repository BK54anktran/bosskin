-- =====================================================================
-- V7 · Bắt đổi mật khẩu lần đầu (Mốc 1, còn lại)
-- Tài khoản do người khác đặt mật khẩu (admin tạo NV, system admin tạo công ty, import, đồng bộ)
-- phải đổi mật khẩu ở lần đăng nhập đầu; trước khi đổi chỉ gọi được API xem hồ sơ / đổi mật khẩu.
-- Tài khoản đã có trước migration không bị bắt đổi (DEFAULT 0).
-- =====================================================================
ALTER TABLE users
  ADD COLUMN must_change_password TINYINT(1) NOT NULL DEFAULT 0;
