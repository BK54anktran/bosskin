-- =============================================
-- V4: Alter existing tables for multi-tenant
-- =============================================

-- Departments: thêm company_id + parent_id (unlimited tree)
ALTER TABLE departments
    ADD COLUMN company_id BIGINT AFTER id,
    ADD COLUMN parent_id  BIGINT DEFAULT NULL AFTER manager_id,
    ADD COLUMN level      INT    NOT NULL DEFAULT 0 AFTER parent_id,
    ADD CONSTRAINT fk_dept_company FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE,
    ADD CONSTRAINT fk_dept_parent  FOREIGN KEY (parent_id)  REFERENCES departments (id) ON DELETE SET NULL;

-- Employees: thêm company_id
ALTER TABLE employees
    ADD COLUMN company_id BIGINT AFTER id,
    ADD CONSTRAINT fk_emp_company FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE;

-- Users: thêm company_id, xóa role enum cũ
ALTER TABLE users
    ADD COLUMN company_id BIGINT AFTER id,
    ADD CONSTRAINT fk_user_company FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE;

ALTER TABLE users DROP COLUMN role;

-- User ↔ Role (nhiều role per user)
CREATE TABLE IF NOT EXISTS user_roles
(
    user_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_ur_user FOREIGN KEY (user_id) REFERENCES users    (id) ON DELETE CASCADE,
    CONSTRAINT fk_ur_role FOREIGN KEY (role_id) REFERENCES roles    (id) ON DELETE CASCADE
);

-- =============================================
-- Seed: 1 Company mẫu + System Admin + Roles
-- =============================================

-- Công ty mẫu
INSERT INTO companies (name, code, domain, active, created_at, updated_at) VALUES
('Bosskin Demo Corp', 'CADENA', 'bosskin.local', TRUE, NOW(), NOW());

-- System admin (password: SysAdmin@123)
INSERT INTO system_admins (email, password, name, enabled, created_at, updated_at) VALUES
('sysadmin@bosskin.io',
 '$2b$10$bUxX1BGnkF4UlBPAsOo0xuZYN76A/wTaYntUIPdf2gvpviknfUfjq',
 'System Administrator', TRUE, NOW(), NOW());

-- Gán company_id cho dữ liệu hiện có (employees, departments, users)
UPDATE departments SET company_id = 1 WHERE company_id IS NULL;
UPDATE employees   SET company_id = 1 WHERE company_id IS NULL;
UPDATE users       SET company_id = 1 WHERE company_id IS NULL;

-- NOT NULL sau khi đã fill data
ALTER TABLE departments MODIFY COLUMN company_id BIGINT NOT NULL;
ALTER TABLE employees   MODIFY COLUMN company_id BIGINT NOT NULL;
ALTER TABLE users       MODIFY COLUMN company_id BIGINT NOT NULL;

-- Tạo roles mặc định cho Bosskin Demo Corp
INSERT INTO roles (company_id, name, description, is_default, created_at, updated_at) VALUES
(1, 'Company Admin',   'Toàn quyền trong công ty',                      FALSE, NOW(), NOW()),
(1, 'HR Manager',      'Quản lý nhân sự, chấm công, lương',             TRUE,  NOW(), NOW()),
(1, 'Accountant',      'Xem và xử lý bảng lương',                       TRUE,  NOW(), NOW()),
(1, 'Department Head', 'Quản lý phòng ban và nhân viên trong phòng',    TRUE,  NOW(), NOW()),
(1, 'Employee',        'Chỉ xem thông tin cá nhân và chấm công',        TRUE,  NOW(), NOW());

-- Gán permissions cho từng role
-- Company Admin: toàn quyền
INSERT INTO role_permissions (role_id, permission_id)
SELECT 1, id FROM permissions;

-- HR Manager: nhân sự + chấm công + xem lương
INSERT INTO role_permissions (role_id, permission_id)
SELECT 2, id FROM permissions
WHERE code IN ('DASHBOARD_VIEW',
               'EMPLOYEE_VIEW','EMPLOYEE_CREATE','EMPLOYEE_UPDATE',
               'DEPARTMENT_VIEW','SHIFT_VIEW','SHIFT_MANAGE',
               'ATTENDANCE_VIEW','ATTENDANCE_MANAGE',
               'PAYROLL_VIEW','PAYROLL_CREATE','ROLE_VIEW');

-- Accountant: lương
INSERT INTO role_permissions (role_id, permission_id)
SELECT 3, id FROM permissions
WHERE code IN ('DASHBOARD_VIEW',
               'EMPLOYEE_VIEW','PAYROLL_VIEW','PAYROLL_CREATE',
               'PAYROLL_APPROVE','PAYROLL_PAY');

-- Department Head: xem nhân viên + phòng ban + chấm công
INSERT INTO role_permissions (role_id, permission_id)
SELECT 4, id FROM permissions
WHERE code IN ('DASHBOARD_VIEW',
               'EMPLOYEE_VIEW','DEPARTMENT_VIEW','DEPARTMENT_MANAGE',
               'SHIFT_VIEW','SHIFT_MANAGE',
               'ATTENDANCE_VIEW','ATTENDANCE_MANAGE','PAYROLL_VIEW');

-- Employee: chỉ xem
INSERT INTO role_permissions (role_id, permission_id)
SELECT 5, id FROM permissions
WHERE code IN ('DASHBOARD_VIEW',
               'EMPLOYEE_VIEW','ATTENDANCE_VIEW','PAYROLL_VIEW');

-- Gán role Company Admin cho admin user hiện có
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, 1 FROM users u WHERE u.email = 'admin@bosskin.vn';

-- Gán role HR Manager cho hr user hiện có
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, 2 FROM users u WHERE u.email = 'hr@bosskin.vn';
