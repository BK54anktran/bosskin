-- Ngôn ngữ ưa dùng của người dùng ('vi' | 'en'), cập nhật mỗi khi app gọi API kèm Accept-Language.
-- Dùng để gửi thông báo đẩy đúng ngôn ngữ (người gửi chạy ở job nền hoặc trong request của người khác nên không biết ngôn ngữ người nhận). NULL = vi.
ALTER TABLE users ADD COLUMN language VARCHAR(5) NULL;
