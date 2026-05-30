CREATE TABLE work_shifts (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    company_id      BIGINT       NOT NULL,
    name            VARCHAR(100) NOT NULL,
    code            VARCHAR(20)  NOT NULL,
    type            ENUM('WORK','HALF_AM','HALF_PM','DAY_OFF','HOLIDAY') NOT NULL DEFAULT 'WORK',
    start_time      TIME,
    end_time        TIME,
    break_start     TIME,
    break_end       TIME,
    work_minutes    INT,
    color           VARCHAR(7)   NOT NULL DEFAULT '#1976D2',
    active          BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_company_code (company_id, code),
    KEY idx_shift_company (company_id),
    CONSTRAINT fk_shift_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
);

-- Which shifts are available per department
CREATE TABLE department_shifts (
    department_id   BIGINT NOT NULL,
    shift_id        BIGINT NOT NULL,
    PRIMARY KEY (department_id, shift_id),
    CONSTRAINT fk_deptshift_dept  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE,
    CONSTRAINT fk_deptshift_shift FOREIGN KEY (shift_id)      REFERENCES work_shifts(id)  ON DELETE CASCADE
);
