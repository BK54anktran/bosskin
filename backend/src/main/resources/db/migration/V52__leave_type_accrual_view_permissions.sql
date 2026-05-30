INSERT INTO permissions (code, description, module)
SELECT 'LEAVE_TYPE_VIEW', 'Xem danh sách loại nghỉ', 'LEAVE'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'LEAVE_TYPE_VIEW');

INSERT INTO permissions (code, description, module)
SELECT 'LEAVE_ACCRUAL_VIEW', 'Xem cài đặt rule cộng phép', 'LEAVE'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'LEAVE_ACCRUAL_VIEW');
