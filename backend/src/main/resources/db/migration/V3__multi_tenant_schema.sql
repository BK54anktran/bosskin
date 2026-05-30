-- =============================================
-- V3: Multi-tenant — System Admin, Company, Permission, Role
-- =============================================

CREATE TABLE IF NOT EXISTS system_admins
(
    id         BIGINT AUTO_INCREMENT PRIMARY KEY,
    email      VARCHAR(100) NOT NULL UNIQUE,
    password   VARCHAR(255) NOT NULL,
    name       VARCHAR(100) NOT NULL,
    enabled    BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at DATETIME(6)  NOT NULL,
    updated_at DATETIME(6)  NOT NULL
);

CREATE TABLE IF NOT EXISTS companies
(
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    code        VARCHAR(50)  NOT NULL UNIQUE,
    domain      VARCHAR(100),
    logo        VARCHAR(255),
    address     TEXT,
    phone       VARCHAR(20),
    email       VARCHAR(100),
    active      BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at  DATETIME(6) NOT NULL,
    updated_at  DATETIME(6) NOT NULL
);

CREATE TABLE IF NOT EXISTS permissions
(
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    code        VARCHAR(50)  NOT NULL UNIQUE,
    description VARCHAR(200) NOT NULL,
    module      VARCHAR(50)  NOT NULL
);

CREATE TABLE IF NOT EXISTS roles
(
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    company_id  BIGINT       NOT NULL,
    name        VARCHAR(100) NOT NULL,
    description VARCHAR(200),
    is_default  BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  DATETIME(6)  NOT NULL,
    updated_at  DATETIME(6)  NOT NULL,
    CONSTRAINT fk_role_company FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE,
    UNIQUE KEY uq_role_name (company_id, name)
);

CREATE TABLE IF NOT EXISTS role_permissions
(
    role_id       BIGINT NOT NULL,
    permission_id BIGINT NOT NULL,
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_rp_role FOREIGN KEY (role_id)       REFERENCES roles       (id) ON DELETE CASCADE,
    CONSTRAINT fk_rp_perm FOREIGN KEY (permission_id) REFERENCES permissions (id) ON DELETE CASCADE
);

-- =============================================
-- Seed: predefined permissions
-- =============================================
INSERT INTO permissions (code, description, module) VALUES
-- Dashboard
('DASHBOARD_VIEW',      'Hiển thị mục Tổng quan trên menu', 'DASHBOARD'),
-- Employee
('EMPLOYEE_VIEW',       'Xem danh sách nhân viên',        'EMPLOYEE'),
('EMPLOYEE_CREATE',     'Thêm nhân viên mới',             'EMPLOYEE'),
('EMPLOYEE_UPDATE',     'Cập nhật thông tin nhân viên',   'EMPLOYEE'),
('EMPLOYEE_DELETE',     'Xóa/vô hiệu hóa nhân viên',     'EMPLOYEE'),
-- Department
('DEPARTMENT_VIEW',     'Xem cơ cấu phòng ban',           'DEPARTMENT'),
('DEPARTMENT_MANAGE',   'Tạo/sửa/xóa phòng ban',         'DEPARTMENT'),
-- Attendance
('ATTENDANCE_VIEW',     'Xem dữ liệu chấm công',          'ATTENDANCE'),
('ATTENDANCE_MANAGE',   'Chỉnh sửa chấm công',           'ATTENDANCE'),
-- Shift
('SHIFT_VIEW',          'Xem ca làm',                    'SHIFT'),
('SHIFT_MANAGE',        'Quản lý ca làm',                'SHIFT'),
-- Payroll
('PAYROLL_VIEW',        'Xem bảng lương',                 'PAYROLL'),
('PAYROLL_CREATE',      'Tạo bảng lương',                 'PAYROLL'),
('PAYROLL_APPROVE',     'Phê duyệt bảng lương',          'PAYROLL'),
('PAYROLL_PAY',         'Đánh dấu đã thanh toán lương',  'PAYROLL'),
-- Role & User
('ROLE_VIEW',           'Xem danh sách vai trò',          'ROLE'),
('ROLE_MANAGE',         'Tạo/sửa/xóa vai trò',           'ROLE'),
('USER_MANAGE',         'Quản lý tài khoản người dùng',  'USER'),
-- Company admin
('COMPANY_MANAGE',      'Toàn quyền quản trị công ty',   'COMPANY');
