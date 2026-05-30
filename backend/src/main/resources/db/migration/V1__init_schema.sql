-- =============================================
-- Bosskin - Initial Database Schema
-- =============================================

CREATE TABLE IF NOT EXISTS departments
(
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    code        VARCHAR(20)  NOT NULL UNIQUE,
    description TEXT,
    manager_id  BIGINT,
    created_at  DATETIME(6)  NOT NULL,
    updated_at  DATETIME(6)  NOT NULL
);

CREATE TABLE IF NOT EXISTS positions
(
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100)   NOT NULL,
    code          VARCHAR(20)    NOT NULL UNIQUE,
    department_id BIGINT         NOT NULL,
    description   TEXT,
    min_salary    DECIMAL(15, 2),
    max_salary    DECIMAL(15, 2),
    created_at    DATETIME(6)    NOT NULL,
    updated_at    DATETIME(6)    NOT NULL,
    CONSTRAINT fk_position_dept FOREIGN KEY (department_id) REFERENCES departments (id)
);

CREATE TABLE IF NOT EXISTS employees
(
    id               BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_code    VARCHAR(20)    NOT NULL UNIQUE,
    full_name        VARCHAR(100)   NOT NULL,
    email            VARCHAR(100)   NOT NULL UNIQUE,
    phone            VARCHAR(15),
    avatar           VARCHAR(255),
    gender           ENUM('MALE','FEMALE','OTHER') NOT NULL,
    date_of_birth    DATE,
    join_date        DATE           NOT NULL,
    leave_date       DATE,
    status           ENUM('ACTIVE','INACTIVE','ON_LEAVE') NOT NULL DEFAULT 'ACTIVE',
    department_id    BIGINT         NOT NULL,
    position_id      BIGINT         NOT NULL,
    base_salary      DECIMAL(15, 2) NOT NULL,
    address          TEXT,
    identity_card    VARCHAR(20),
    bank_account     VARCHAR(30),
    bank_name        VARCHAR(100),
    created_at       DATETIME(6)    NOT NULL,
    updated_at       DATETIME(6)    NOT NULL,
    CONSTRAINT fk_employee_dept FOREIGN KEY (department_id) REFERENCES departments (id),
    CONSTRAINT fk_employee_pos  FOREIGN KEY (position_id)  REFERENCES positions (id)
);

ALTER TABLE departments
    ADD CONSTRAINT fk_dept_manager FOREIGN KEY (manager_id) REFERENCES employees (id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS users
(
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    email       VARCHAR(100) NOT NULL UNIQUE,
    password    VARCHAR(255) NOT NULL,
    role        ENUM('ADMIN','HR_MANAGER','HR_STAFF','EMPLOYEE') NOT NULL,
    employee_id BIGINT UNIQUE,
    enabled     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  DATETIME(6)  NOT NULL,
    updated_at  DATETIME(6)  NOT NULL,
    CONSTRAINT fk_user_employee FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS attendances
(
    id             BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id    BIGINT NOT NULL,
    date           DATE   NOT NULL,
    check_in       DATETIME(6),
    check_out      DATETIME(6),
    status         ENUM('PRESENT','ABSENT','LATE','HALF_DAY','LEAVE') NOT NULL,
    working_hours  DOUBLE,
    overtime_hours DOUBLE DEFAULT 0,
    note           TEXT,
    created_at     DATETIME(6) NOT NULL,
    updated_at     DATETIME(6) NOT NULL,
    UNIQUE KEY uq_attendance (employee_id, date),
    CONSTRAINT fk_attendance_employee FOREIGN KEY (employee_id) REFERENCES employees (id)
);

CREATE TABLE IF NOT EXISTS payrolls
(
    id                      BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id             BIGINT         NOT NULL,
    year                    INT            NOT NULL,
    month                   INT            NOT NULL,
    base_salary             DECIMAL(15, 2) NOT NULL,
    allowance               DECIMAL(15, 2) NOT NULL DEFAULT 0,
    bonus                   DECIMAL(15, 2) NOT NULL DEFAULT 0,
    overtime_pay            DECIMAL(15, 2) NOT NULL DEFAULT 0,
    gross_salary            DECIMAL(15, 2) NOT NULL,
    social_insurance        DECIMAL(15, 2) NOT NULL,
    health_insurance        DECIMAL(15, 2) NOT NULL,
    unemployment_insurance  DECIMAL(15, 2) NOT NULL,
    personal_income_tax     DECIMAL(15, 2) NOT NULL,
    other_deductions        DECIMAL(15, 2) NOT NULL DEFAULT 0,
    net_salary              DECIMAL(15, 2) NOT NULL,
    status                  ENUM('DRAFT','APPROVED','PAID') NOT NULL DEFAULT 'DRAFT',
    note                    TEXT,
    paid_at                 DATETIME(6),
    approved_at             DATETIME(6),
    created_at              DATETIME(6)    NOT NULL,
    updated_at              DATETIME(6)    NOT NULL,
    UNIQUE KEY uq_payroll (employee_id, year, month),
    CONSTRAINT fk_payroll_employee FOREIGN KEY (employee_id) REFERENCES employees (id)
);

CREATE TABLE IF NOT EXISTS leave_requests
(
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    type        ENUM('ANNUAL','SICK','MATERNITY','PATERNITY','UNPAID','OTHER') NOT NULL,
    start_date  DATE   NOT NULL,
    end_date    DATE   NOT NULL,
    days        INT    NOT NULL,
    reason      TEXT,
    status      ENUM('PENDING','APPROVED','REJECTED','CANCELLED') NOT NULL DEFAULT 'PENDING',
    approved_by BIGINT,
    note        TEXT,
    created_at  DATETIME(6) NOT NULL,
    updated_at  DATETIME(6) NOT NULL,
    CONSTRAINT fk_leave_employee FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT fk_leave_approver FOREIGN KEY (approved_by) REFERENCES users (id)
);

-- Indexes
CREATE INDEX idx_employee_dept   ON employees (department_id);
CREATE INDEX idx_employee_status ON employees (status);
CREATE INDEX idx_attendance_date ON attendances (date);
CREATE INDEX idx_attendance_emp  ON attendances (employee_id);
CREATE INDEX idx_payroll_month   ON payrolls (year, month);
