-- Gói chức năng theo công ty (core/CompanyModules): system admin tắt từng gói (ATTENDANCE, SHIFT, LEAVE, PAYROLL, CONTRACT,
-- DOCUMENT, REPORT). Lưu danh sách gói TẮT, cách nhau dấu phẩy; NULL = bật hết (mọi công ty hiện có giữ nguyên).
ALTER TABLE companies ADD COLUMN disabled_modules varchar(200) DEFAULT NULL;
