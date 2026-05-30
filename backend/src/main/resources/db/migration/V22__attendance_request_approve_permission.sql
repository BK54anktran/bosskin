INSERT INTO permissions (code, description, module)
SELECT 'ATTENDANCE_REQUEST_APPROVE', 'Duyệt yêu cầu chấm công', 'ATTENDANCE'
WHERE NOT EXISTS (
    SELECT 1 FROM permissions WHERE code = 'ATTENDANCE_REQUEST_APPROVE'
);

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code = 'ATTENDANCE_REQUEST_APPROVE'
WHERE r.name IN ('HR Manager', 'Department Head')
  AND NOT EXISTS (
      SELECT 1
      FROM role_permissions rp
      WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );
