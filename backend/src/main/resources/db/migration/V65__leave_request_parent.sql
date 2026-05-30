ALTER TABLE leave_requests
    ADD COLUMN parent_id BIGINT NULL,
    ADD CONSTRAINT fk_lr_parent FOREIGN KEY (parent_id) REFERENCES leave_requests(id) ON DELETE CASCADE;

CREATE INDEX idx_lr_parent ON leave_requests(parent_id);
