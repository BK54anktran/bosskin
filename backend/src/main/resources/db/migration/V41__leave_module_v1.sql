CREATE TABLE IF NOT EXISTS leave_types (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    company_id BIGINT NOT NULL,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    unit ENUM('DAY','HOUR') NOT NULL,
    is_paid BOOLEAN NOT NULL DEFAULT TRUE,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    description VARCHAR(255),
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_leave_type_company FOREIGN KEY (company_id) REFERENCES companies(id),
    CONSTRAINT uk_leave_type_company_code UNIQUE (company_id, code)
);

CREATE TABLE IF NOT EXISTS leave_accrual_rules (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    company_id BIGINT NOT NULL,
    leave_type_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    grant_amount DECIMAL(10,2) NOT NULL,
    frequency ENUM('MONTHLY','YEARLY') NOT NULL,
    day_of_month INT,
    month_of_year INT,
    min_tenure_years INT NOT NULL DEFAULT 0,
    valid_from DATE,
    valid_to DATE,
    expire_after_days INT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_leave_rule_company FOREIGN KEY (company_id) REFERENCES companies(id),
    CONSTRAINT fk_leave_rule_type FOREIGN KEY (leave_type_id) REFERENCES leave_types(id)
);

CREATE TABLE IF NOT EXISTS leave_grants (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    company_id BIGINT NOT NULL,
    employee_id BIGINT NOT NULL,
    leave_type_id BIGINT NOT NULL,
    source ENUM('MANUAL','AUTO') NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    used_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    granted_at DATE NOT NULL,
    valid_from DATE,
    valid_to DATE,
    note VARCHAR(500),
    accrual_rule_id BIGINT,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_leave_grant_company FOREIGN KEY (company_id) REFERENCES companies(id),
    CONSTRAINT fk_leave_grant_employee FOREIGN KEY (employee_id) REFERENCES employees(id),
    CONSTRAINT fk_leave_grant_type FOREIGN KEY (leave_type_id) REFERENCES leave_types(id),
    CONSTRAINT fk_leave_grant_rule FOREIGN KEY (accrual_rule_id) REFERENCES leave_accrual_rules(id)
);

CREATE TABLE IF NOT EXISTS leave_requests (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    company_id BIGINT NOT NULL,
    employee_id BIGINT NOT NULL,
    leave_type_id BIGINT NOT NULL,
    mode ENUM('DAY_RANGE','HOUR_RANGE') NOT NULL,
    from_date DATE NOT NULL,
    to_date DATE NOT NULL,
    from_time TIME,
    to_time TIME,
    requested_amount DECIMAL(10,2) NOT NULL,
    status ENUM('PENDING','APPROVED','REJECTED','CANCELLED') NOT NULL DEFAULT 'PENDING',
    reason VARCHAR(500),
    admin_note VARCHAR(500),
    processed_by BIGINT,
    processed_at DATETIME(6),
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_leave_req_company FOREIGN KEY (company_id) REFERENCES companies(id),
    CONSTRAINT fk_leave_req_employee FOREIGN KEY (employee_id) REFERENCES employees(id),
    CONSTRAINT fk_leave_req_type FOREIGN KEY (leave_type_id) REFERENCES leave_types(id),
    CONSTRAINT fk_leave_req_processed_by FOREIGN KEY (processed_by) REFERENCES users(id)
);

INSERT INTO permissions (code, description, module)
SELECT 'LEAVE_VIEW', 'Xem đơn nghỉ và số phép', 'LEAVE'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'LEAVE_VIEW');

INSERT INTO permissions (code, description, module)
SELECT 'LEAVE_REQUEST_CREATE', 'Tạo đơn nghỉ', 'LEAVE'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'LEAVE_REQUEST_CREATE');

INSERT INTO permissions (code, description, module)
SELECT 'LEAVE_REQUEST_APPROVE', 'Duyệt/Từ chối đơn nghỉ', 'LEAVE'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'LEAVE_REQUEST_APPROVE');

INSERT INTO permissions (code, description, module)
SELECT 'LEAVE_TYPE_MANAGE', 'Quản lý loại nghỉ', 'LEAVE'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'LEAVE_TYPE_MANAGE');

INSERT INTO permissions (code, description, module)
SELECT 'LEAVE_GRANT_MANUAL', 'Cấp phép thủ công', 'LEAVE'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'LEAVE_GRANT_MANUAL');

INSERT INTO permissions (code, description, module)
SELECT 'LEAVE_ACCRUAL_MANAGE', 'Quản lý rule cộng phép tự động', 'LEAVE'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'LEAVE_ACCRUAL_MANAGE');
