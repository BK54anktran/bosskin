-- Bước C — xác thực 2 lớp (TOTP, kiểu Google Authenticator).
-- totp_secret: khoá base32 (đặt khi bắt đầu cài; totp_enabled = 1 sau khi nhập đúng mã lần đầu).
-- totp_recovery_codes: JSON mảng mã dự phòng đã băm bcrypt, mỗi mã dùng một lần.
ALTER TABLE users
  ADD COLUMN totp_secret varchar(64) DEFAULT NULL,
  ADD COLUMN totp_enabled tinyint(1) NOT NULL DEFAULT 0,
  ADD COLUMN totp_recovery_codes text DEFAULT NULL;

ALTER TABLE system_admins
  ADD COLUMN totp_secret varchar(64) DEFAULT NULL,
  ADD COLUMN totp_enabled tinyint(1) NOT NULL DEFAULT 0,
  ADD COLUMN totp_recovery_codes text DEFAULT NULL;

-- System admin bật để bắt buộc 2FA với người có quyền quản trị (ROLE_MANAGE) của công ty
ALTER TABLE companies
  ADD COLUMN require_admin_2fa tinyint(1) NOT NULL DEFAULT 0;
