CREATE TABLE IF NOT EXISTS attendance_requests
(
    id                         BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id                BIGINT       NOT NULL,
    request_date               DATE         NOT NULL,
    request_type               VARCHAR(20)  NOT NULL,
    requested_check_in         TIME,
    requested_check_out        TIME,
    requested_overtime_minutes INT,
    note                       TEXT,
    status                     VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    admin_note                 TEXT,
    processed_by               BIGINT,
    processed_at               DATETIME(6),
    created_at                 DATETIME(6)  NOT NULL,
    updated_at                 DATETIME(6)  NOT NULL,
    CONSTRAINT fk_attendance_request_employee
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
    CONSTRAINT fk_attendance_request_processed_by
        FOREIGN KEY (processed_by) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT uq_attendance_request_employee_date_type
        UNIQUE (employee_id, request_date, request_type)
);

