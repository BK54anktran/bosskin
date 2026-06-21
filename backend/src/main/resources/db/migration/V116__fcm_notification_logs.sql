CREATE TABLE fcm_notification_logs (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id         BIGINT       NOT NULL,
    fcm_token       VARCHAR(512) NOT NULL,
    shift_name      VARCHAR(100) NOT NULL,
    shift_start     TIME         NOT NULL,
    work_date       DATE         NOT NULL,
    minutes_before  INT          NOT NULL,
    status          VARCHAR(20)  NOT NULL COMMENT 'SUCCESS | FAILED',
    error_message   VARCHAR(500) NULL,
    sent_at         DATETIME     NOT NULL
);
