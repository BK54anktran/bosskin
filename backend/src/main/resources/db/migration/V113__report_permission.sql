-- Add REPORT_VIEW permission and grant to roles with PAYROLL_VIEW (ADMIN, HR_MANAGER)

INSERT IGNORE INTO permissions (code, description, module) VALUES
('REPORT_VIEW', 'Xem và xuất báo cáo nhân sự', 'REPORT');

INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code = 'REPORT_VIEW'
WHERE r.id IN (
    SELECT DISTINCT rp.role_id
    FROM role_permissions rp
    JOIN permissions perm ON perm.id = rp.permission_id
    WHERE perm.code = 'PAYROLL_VIEW'
);
