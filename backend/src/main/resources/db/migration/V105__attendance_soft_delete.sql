ALTER TABLE attendances
    ADD COLUMN deleted      TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN deleted_at   DATETIME   NULL,
    ADD COLUMN deleted_by_id BIGINT    NULL,
    ADD CONSTRAINT fk_attendance_deleted_by FOREIGN KEY (deleted_by_id) REFERENCES users(id);
