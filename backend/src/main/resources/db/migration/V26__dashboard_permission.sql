-- Add dashboard permission to existing databases

INSERT IGNORE INTO permissions (code, description, module) VALUES
('DASHBOARD_VIEW', 'Hiển thị mục Tổng quan trên menu', 'DASHBOARD');

-- Grant dashboard to all existing roles so current behavior stays consistent.
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code = 'DASHBOARD_VIEW';
