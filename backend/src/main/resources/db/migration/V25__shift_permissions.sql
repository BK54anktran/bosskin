-- Add shift permissions to existing databases

INSERT IGNORE INTO permissions (code, description, module) VALUES
('SHIFT_VIEW',   'Xem ca làm',   'SHIFT'),
('SHIFT_MANAGE', 'Quản lý ca làm', 'SHIFT');

-- Company Admin should keep receiving all permissions
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT 1, p.id
FROM permissions p
WHERE p.code IN ('SHIFT_VIEW', 'SHIFT_MANAGE');

-- HR Manager and Department Head can manage shifts
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT 2, p.id
FROM permissions p
WHERE p.code IN ('SHIFT_VIEW', 'SHIFT_MANAGE');

INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT 4, p.id
FROM permissions p
WHERE p.code IN ('SHIFT_VIEW', 'SHIFT_MANAGE');
