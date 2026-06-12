CREATE TABLE excel_history (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    company_id  BIGINT       NOT NULL,
    user_id     BIGINT       NOT NULL,
    type        ENUM('EXPORT','IMPORT') NOT NULL,
    filename    VARCHAR(255) NOT NULL,
    file_url    VARCHAR(1024),
    ok_count    INT,
    error_count INT,
    skip_count  INT,
    created_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    INDEX idx_excel_history_company (company_id),
    INDEX idx_excel_history_user    (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
