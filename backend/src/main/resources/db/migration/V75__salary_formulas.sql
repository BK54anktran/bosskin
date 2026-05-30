CREATE TABLE salary_formulas (
    id               BIGINT AUTO_INCREMENT PRIMARY KEY,
    position_id      BIGINT NOT NULL,
    effective_date   DATE   NOT NULL,
    expression_gross TEXT   NOT NULL,
    expression_net   TEXT   NOT NULL,
    created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_sf_position FOREIGN KEY (position_id) REFERENCES positions (id)
);

CREATE INDEX idx_sf_position_date ON salary_formulas (position_id, effective_date DESC);
