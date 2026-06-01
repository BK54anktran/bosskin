ALTER TABLE shift_assignments
    ADD COLUMN snapshot_name        VARCHAR(100)  NULL,
    ADD COLUMN snapshot_code        VARCHAR(20)   NULL,
    ADD COLUMN snapshot_type        VARCHAR(20)   NULL,
    ADD COLUMN snapshot_start_time  TIME          NULL,
    ADD COLUMN snapshot_end_time    TIME          NULL,
    ADD COLUMN snapshot_break_start TIME          NULL,
    ADD COLUMN snapshot_break_end   TIME          NULL,
    ADD COLUMN snapshot_work_minutes INT          NULL,
    ADD COLUMN snapshot_color       VARCHAR(7)    NULL;

-- Back-fill existing rows from the shift template (shift may already be soft-deleted)
UPDATE shift_assignments sa
    JOIN work_shifts ws ON ws.id = sa.shift_id
SET sa.snapshot_name         = ws.name,
    sa.snapshot_code         = ws.code,
    sa.snapshot_type         = ws.type,
    sa.snapshot_start_time   = ws.start_time,
    sa.snapshot_end_time     = ws.end_time,
    sa.snapshot_break_start  = ws.break_start,
    sa.snapshot_break_end    = ws.break_end,
    sa.snapshot_work_minutes = ws.work_minutes,
    sa.snapshot_color        = ws.color
WHERE sa.shift_id IS NOT NULL
  AND sa.deleted = false;
