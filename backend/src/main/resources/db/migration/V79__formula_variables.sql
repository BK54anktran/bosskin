CREATE TABLE formula_variables (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    company_id  BIGINT       NOT NULL,
    name        VARCHAR(50)  NOT NULL,
    label       VARCHAR(100) NOT NULL,
    expression  TEXT         NOT NULL,
    created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_fv_company FOREIGN KEY (company_id) REFERENCES companies (id),
    UNIQUE KEY uq_fv_company_name (company_id, name)
);
