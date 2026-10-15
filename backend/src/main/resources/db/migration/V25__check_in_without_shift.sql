-- Cho phép tự chấm vào / ra vào ngày không được xếp ca (cài đặt công ty, mặc định tắt = chỉ chấm theo ca như cũ).
ALTER TABLE companies ADD COLUMN check_in_without_shift tinyint(1) NOT NULL DEFAULT 0;
