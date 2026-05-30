-- =============================================
-- V5: Profile edit requests
-- =============================================

ALTER TABLE employees
    ADD COLUMN personal_email VARCHAR(100) AFTER phone;

CREATE TABLE IF NOT EXISTS profile_edit_requests
(
    id             BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id    BIGINT       NOT NULL,
    full_name      VARCHAR(100),
    gender         ENUM('MALE','FEMALE','OTHER'),
    date_of_birth  DATE,
    phone          VARCHAR(15),
    personal_email VARCHAR(100),
    avatar_url     VARCHAR(255),
    status         ENUM('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING',
    admin_note     TEXT,
    processed_by   BIGINT,
    created_at     DATETIME(6) NOT NULL,
    updated_at     DATETIME(6) NOT NULL,
    CONSTRAINT fk_per_employee  FOREIGN KEY (employee_id)  REFERENCES employees (id) ON DELETE CASCADE,
    CONSTRAINT fk_per_admin     FOREIGN KEY (processed_by) REFERENCES users (id) ON DELETE SET NULL
);
