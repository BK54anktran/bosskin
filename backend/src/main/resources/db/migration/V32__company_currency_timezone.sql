-- Công ty ở nước khác: múi giờ (chấm công, ca, ngày công tính theo giờ địa phương của công ty) và tiền tệ hiển thị.
-- Mặc định giữ nguyên hành vi cũ (Việt Nam, VND).
ALTER TABLE companies
    ADD COLUMN currency_code VARCHAR(3)  NOT NULL DEFAULT 'VND' AFTER domain,
    ADD COLUMN timezone      VARCHAR(40) NOT NULL DEFAULT 'Asia/Ho_Chi_Minh' AFTER currency_code;
