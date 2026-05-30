INSERT INTO permissions (code, description, module, required_rule)
SELECT 'LEAVE_REQUEST_CREATE_FOR_OTHERS', 'Tạo đơn nghỉ phép hộ nhân viên khác', 'LEAVE', 'LEAVE_REQUEST_CREATE'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'LEAVE_REQUEST_CREATE_FOR_OTHERS');
