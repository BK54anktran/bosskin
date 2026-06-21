ALTER TABLE users
    ADD COLUMN fcm_token           VARCHAR(512) NULL,
    ADD COLUMN shift_reminder_minutes INT        NULL;
