-- V30: vai trò hệ thống (Admin sinh sẵn khi tạo công ty) bị khoá — công ty không sửa quyền / đổi tên / xoá được.
ALTER TABLE roles ADD COLUMN is_system tinyint(1) NOT NULL DEFAULT 0 AFTER is_default;

-- Công ty cũ: vai trò Admin = các vai trò của tài khoản đầu tiên của công ty (tài khoản admin tạo cùng công ty).
UPDATE roles r
JOIN (SELECT company_id, MIN(id) AS user_id FROM users WHERE deleted = 0 GROUP BY company_id) f ON f.company_id = r.company_id
JOIN user_roles ur ON ur.user_id = f.user_id AND ur.role_id = r.id
SET r.is_system = 1
WHERE r.deleted = 0;
