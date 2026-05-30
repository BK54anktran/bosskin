-- Per-permission department scope: restricts a specific permission to certain departments
-- Empty = permission applies to all departments
CREATE TABLE user_permission_dept_scopes
(
    user_id         BIGINT       NOT NULL,
    permission_code VARCHAR(50)  NOT NULL,
    department_id   BIGINT       NOT NULL,
    PRIMARY KEY (user_id, permission_code, department_id),
    CONSTRAINT fk_upds_user FOREIGN KEY (user_id)       REFERENCES users       (id) ON DELETE CASCADE,
    CONSTRAINT fk_upds_dept FOREIGN KEY (department_id) REFERENCES departments (id) ON DELETE CASCADE
);
