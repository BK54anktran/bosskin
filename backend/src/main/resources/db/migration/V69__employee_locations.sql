CREATE TABLE employee_locations (
    id            BIGINT      NOT NULL AUTO_INCREMENT,
    employee_id   BIGINT      NOT NULL,
    name          VARCHAR(100) NOT NULL,
    latitude      DOUBLE      NOT NULL,
    longitude     DOUBLE      NOT NULL,
    radius_meters INT         NOT NULL DEFAULT 100,
    PRIMARY KEY (id),
    CONSTRAINT fk_emp_loc_employee FOREIGN KEY (employee_id)
        REFERENCES employees (id) ON DELETE CASCADE
);

CREATE INDEX idx_emp_loc_employee ON employee_locations (employee_id);
