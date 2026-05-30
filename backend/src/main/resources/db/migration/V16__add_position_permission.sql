INSERT INTO permissions (code, description, module) VALUES
('POSITION_MANAGE', 'Tạo/sửa/xóa chức vụ', 'DEPARTMENT');

-- Grant to Company Admin role (role_id = 1)
INSERT INTO role_permissions (role_id, permission_id)
SELECT 1, id FROM permissions WHERE code = 'POSITION_MANAGE';

-- Grant to Department Head role (role_id = 4)
INSERT INTO role_permissions (role_id, permission_id)
SELECT 4, id FROM permissions WHERE code = 'POSITION_MANAGE';
