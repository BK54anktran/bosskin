CREATE TABLE attendance_approve_leaves (
    id                BIGINT       NOT NULL AUTO_INCREMENT,
    attendance_id     BIGINT       NOT NULL,
    leave_request_id  BIGINT       NOT NULL,
    leave_type_name   VARCHAR(100) NOT NULL,
    paid              BOOLEAN      NOT NULL DEFAULT FALSE,
    leave_hours       DOUBLE       NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CONSTRAINT fk_aal_attendance  FOREIGN KEY (attendance_id)    REFERENCES attendances(id)     ON DELETE CASCADE,
    CONSTRAINT fk_aal_leave       FOREIGN KEY (leave_request_id) REFERENCES leave_requests(id)  ON DELETE CASCADE
);
