-- =============================================
-- Seed data cho development/testing
-- =============================================

-- Phòng ban
INSERT INTO departments (name, code, description, created_at, updated_at) VALUES
('Ban Giám Đốc',       'BGD',  'Hội đồng quản trị và ban lãnh đạo',    NOW(), NOW()),
('Phòng Kỹ Thuật',     'IT',   'Phát triển phần mềm và hạ tầng IT',    NOW(), NOW()),
('Phòng Kinh Doanh',   'KD',   'Bán hàng và phát triển kinh doanh',    NOW(), NOW()),
('Phòng Nhân Sự',      'HR',   'Quản lý nhân sự và tuyển dụng',        NOW(), NOW()),
('Phòng Kế Toán',      'KT',   'Kế toán và tài chính',                 NOW(), NOW()),
('Phòng Marketing',    'MKT',  'Marketing và truyền thông',             NOW(), NOW());

-- Chức vụ
INSERT INTO positions (name, code, department_id, min_salary, max_salary, created_at, updated_at) VALUES
('Giám Đốc Điều Hành',     'CEO',     1, 50000000, 100000000, NOW(), NOW()),
('Trưởng Phòng Kỹ Thuật',  'CTO',     2, 30000000, 60000000,  NOW(), NOW()),
('Senior Developer',       'SE_SR',   2, 20000000, 40000000,  NOW(), NOW()),
('Junior Developer',       'SE_JR',   2, 10000000, 20000000,  NOW(), NOW()),
('Trưởng Phòng Kinh Doanh','KD_MGR',  3, 20000000, 40000000,  NOW(), NOW()),
('Nhân Viên Kinh Doanh',   'KD_STAFF',3, 8000000,  15000000,  NOW(), NOW()),
('Trưởng Phòng Nhân Sự',   'HR_MGR',  4, 15000000, 30000000,  NOW(), NOW()),
('Chuyên Viên Nhân Sự',    'HR_STAFF',4, 8000000,  15000000,  NOW(), NOW()),
('Kế Toán Trưởng',         'KT_MGR',  5, 15000000, 25000000,  NOW(), NOW()),
('Kế Toán Viên',           'KT_STAFF',5, 8000000,  15000000,  NOW(), NOW());

-- Nhân viên mẫu
INSERT INTO employees (employee_code, full_name, email, phone, gender, join_date, status, department_id, position_id, base_salary, created_at, updated_at) VALUES
('EMP00001', 'Nguyễn Văn Anh',    'anh.nguyen@bosskin.vn',    '0901234501', 'MALE',   '2020-01-15', 'ACTIVE', 1, 1, 50000000, NOW(), NOW()),
('EMP00002', 'Trần Thị Bích',     'bich.tran@bosskin.vn',     '0901234502', 'FEMALE', '2020-03-01', 'ACTIVE', 4, 7, 20000000, NOW(), NOW()),
('EMP00003', 'Lê Văn Cường',      'cuong.le@bosskin.vn',      '0901234503', 'MALE',   '2021-01-10', 'ACTIVE', 2, 2, 35000000, NOW(), NOW()),
('EMP00004', 'Phạm Thị Dung',     'dung.pham@bosskin.vn',     '0901234504', 'FEMALE', '2021-06-01', 'ACTIVE', 2, 3, 25000000, NOW(), NOW()),
('EMP00005', 'Hoàng Văn Em',      'em.hoang@bosskin.vn',      '0901234505', 'MALE',   '2022-02-15', 'ACTIVE', 2, 4, 15000000, NOW(), NOW()),
('EMP00006', 'Vũ Thị Phương',     'phuong.vu@bosskin.vn',     '0901234506', 'FEMALE', '2022-04-01', 'ACTIVE', 3, 5, 22000000, NOW(), NOW()),
('EMP00007', 'Đặng Văn Giang',    'giang.dang@bosskin.vn',    '0901234507', 'MALE',   '2023-01-05', 'ACTIVE', 3, 6, 12000000, NOW(), NOW()),
('EMP00008', 'Bùi Thị Hoa',       'hoa.bui@bosskin.vn',       '0901234508', 'FEMALE', '2023-07-01', 'ACTIVE', 4, 8, 10000000, NOW(), NOW());

-- Tài khoản admin (password: Admin@123)
-- BCrypt hash of "Admin@123"
INSERT INTO users (email, password, role, employee_id, enabled, created_at, updated_at) VALUES
('admin@bosskin.vn',
 '$2b$10$bUxX1BGnkF4UlBPAsOo0xuZYN76A/wTaYntUIPdf2gvpviknfUfjq',
 'ADMIN', NULL, TRUE, NOW(), NOW()),
('hr@bosskin.vn',
 '$2b$10$bUxX1BGnkF4UlBPAsOo0xuZYN76A/wTaYntUIPdf2gvpviknfUfjq',
 'HR_MANAGER', 2, TRUE, NOW(), NOW());
