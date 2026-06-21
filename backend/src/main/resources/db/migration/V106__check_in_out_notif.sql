-- Cài đặt thông báo check-in/out nhanh cho user
ALTER TABLE users
    ADD COLUMN check_in_out_notif_minutes INT NULL
        COMMENT 'Số phút trước ca (check-in) / sau ca (check-out) để gửi thông báo. NULL = tắt';

-- Tracking đã gửi thông báo check-in/out cho từng ca
ALTER TABLE shift_assignments
    ADD COLUMN check_in_notif_sent_at  DATETIME NULL,
    ADD COLUMN check_out_notif_sent_at DATETIME NULL;
