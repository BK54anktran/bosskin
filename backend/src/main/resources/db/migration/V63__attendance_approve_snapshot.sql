ALTER TABLE attendances
    ADD COLUMN approved          BOOLEAN      NOT NULL DEFAULT FALSE,
    ADD COLUMN approved_at       DATETIME     NULL,
    ADD COLUMN approved_by_id    BIGINT       NULL,
    ADD COLUMN snap_actual_hours DOUBLE       NULL,
    ADD COLUMN snap_day_hours    DOUBLE       NULL,
    ADD COLUMN snap_day_ot       DOUBLE       NULL,
    ADD COLUMN snap_night_hours  DOUBLE       NULL,
    ADD COLUMN snap_night_ot     DOUBLE       NULL,
    ADD CONSTRAINT fk_att_approved_by FOREIGN KEY (approved_by_id) REFERENCES users(id);
