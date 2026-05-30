CREATE TABLE role_permission_dept_scopes (
    role_id         BIGINT      NOT NULL,
    permission_code VARCHAR(50) NOT NULL,
    department_id   BIGINT      NOT NULL,
    PRIMARY KEY (role_id, permission_code, department_id),
    CONSTRAINT fk_rpds_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    CONSTRAINT fk_rpds_dept FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE
);
