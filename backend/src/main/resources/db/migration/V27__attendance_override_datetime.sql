-- Giờ vào / ra sửa tay (attendances.override_check_in / _out) trước đây chỉ lưu giờ trong ngày nên ca đêm phải đoán ngày.
-- Đổi sang ngày giờ đầy đủ (datetime): thêm cột mới → đổ dữ liệu cũ → bỏ cột cũ → đổi tên. KHÔNG đổi kiểu tại chỗ
-- (MySQL điền ngày hiện tại khi đổi TIME sang DATETIME). Quy tắc chọn ngày giống core/AttendanceTimes:
--  · giờ vào: ngày công; ca qua đêm mà giờ vào sớm hơn giờ bắt đầu ca hơn 12 giờ = đến muộn qua nửa đêm → hôm sau
--  · giờ ra: ngày của giờ vào (sửa tay, hoặc giờ vào thật nếu chỉ sửa giờ ra), +1 ngày khi không sau giờ vào ("nhỏ hơn thì +1 ngày");
--    chưa biết giờ vào thì ngày công, ca qua đêm mà giờ ra ≤ giờ bắt đầu ca thì +1 ngày.
ALTER TABLE attendances
  ADD COLUMN override_check_in_at  datetime(6) DEFAULT NULL,
  ADD COLUMN override_check_out_at datetime(6) DEFAULT NULL;

UPDATE attendances a
LEFT JOIN shift_assignments s ON s.id = a.shift_assignment_id
SET a.override_check_in_at = TIMESTAMP(a.`date`, a.override_check_in)
    + INTERVAL IF(
        s.id IS NOT NULL
        AND COALESCE(s.custom_end_time, s.snapshot_end_time) <= COALESCE(s.custom_start_time, s.snapshot_start_time)
        AND TIME_TO_SEC(COALESCE(s.custom_start_time, s.snapshot_start_time)) - TIME_TO_SEC(a.override_check_in) > 12 * 3600,
        1, 0) DAY
WHERE a.override_check_in IS NOT NULL;

UPDATE attendances a
LEFT JOIN shift_assignments s ON s.id = a.shift_assignment_id
SET a.override_check_out_at = CASE
    WHEN COALESCE(a.override_check_in_at, a.check_in) IS NOT NULL THEN
        TIMESTAMP(DATE(COALESCE(a.override_check_in_at, a.check_in)), a.override_check_out)
        + INTERVAL IF(TIMESTAMP(DATE(COALESCE(a.override_check_in_at, a.check_in)), a.override_check_out)
                      <= COALESCE(a.override_check_in_at, a.check_in), 1, 0) DAY
    ELSE
        TIMESTAMP(a.`date`, a.override_check_out)
        + INTERVAL IF(s.id IS NOT NULL
                      AND COALESCE(s.custom_end_time, s.snapshot_end_time) <= COALESCE(s.custom_start_time, s.snapshot_start_time)
                      AND a.override_check_out <= COALESCE(s.custom_start_time, s.snapshot_start_time), 1, 0) DAY
    END
WHERE a.override_check_out IS NOT NULL;

ALTER TABLE attendances
  DROP COLUMN override_check_in,
  DROP COLUMN override_check_out;

ALTER TABLE attendances
  RENAME COLUMN override_check_in_at TO override_check_in,
  RENAME COLUMN override_check_out_at TO override_check_out;
