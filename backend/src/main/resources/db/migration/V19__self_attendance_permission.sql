INSERT INTO permissions (code, description, module) VALUES
('ATTENDANCE_SELF', 'Tự check-in/check-out', 'ATTENDANCE');

-- Company Admin, HR Manager, Department Head, Employee
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code = 'ATTENDANCE_SELF'
WHERE r.id IN (1, 2, 4, 5);
