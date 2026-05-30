CREATE TABLE user_sessions (
    id              BIGINT      NOT NULL AUTO_INCREMENT,
    user_id         BIGINT      NOT NULL,
    jti             VARCHAR(36) NOT NULL COMMENT 'JWT ID of the refresh token',
    device_id       VARCHAR(255) NOT NULL,
    expires_at      DATETIME    NOT NULL,
    revoked         BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at      DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_jti (jti),
    KEY idx_session_user (user_id),
    CONSTRAINT fk_session_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
