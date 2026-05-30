ALTER TABLE companies
    ADD COLUMN attendance_day_night_mode BOOLEAN NOT NULL DEFAULT FALSE AFTER self_attendance_enabled,
    ADD COLUMN attendance_ot_enabled BOOLEAN NOT NULL DEFAULT TRUE AFTER attendance_day_night_mode;

INSERT INTO permissions (code, description, module)
SELECT 'COMPANY_SETTING_VIEW', 'Xem cài đặt chung công ty', 'COMPANY_SETTING'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'COMPANY_SETTING_VIEW');

INSERT INTO permissions (code, description, module)
SELECT 'COMPANY_SETTING_MANAGE', 'Quản lý cài đặt chung công ty', 'COMPANY_SETTING'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'COMPANY_SETTING_MANAGE');
