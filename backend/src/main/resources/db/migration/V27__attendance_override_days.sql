-- Sửa tay giờ vào / ra (attendances.override_check_in / _out) chỉ lưu giờ trong ngày. Thêm "số ngày lệch so với ngày công" để ghép
-- lại thành ngày giờ đầy đủ khi tính công (ca đêm: giờ ra +1 ngày; đến muộn qua nửa đêm: giờ vào +1 ngày). Chỉ THÊM cột có mặc định
-- nên bản API cũ vẫn chạy được nếu phải quay lại. Giá trị cho dữ liệu cũ tính theo cùng quy tắc với code (core/AttendanceTimes).

ALTER TABLE attendances
  ADD COLUMN override_check_in_day  tinyint NOT NULL DEFAULT 0,
  ADD COLUMN override_check_out_day tinyint NOT NULL DEFAULT 0;

-- Giờ vào sửa tay của ca qua đêm mà sớm hơn giờ bắt đầu ca hơn 12 giờ = đến muộn qua nửa đêm → hôm sau (+1)
UPDATE attendances a
JOIN shift_assignments s ON s.id = a.shift_assignment_id
SET a.override_check_in_day = 1
WHERE a.override_check_in IS NOT NULL
  AND COALESCE(s.custom_end_time, s.snapshot_end_time) <= COALESCE(s.custom_start_time, s.snapshot_start_time)
  AND TIME_TO_SEC(COALESCE(s.custom_start_time, s.snapshot_start_time)) - TIME_TO_SEC(a.override_check_in) > 12 * 3600;

-- Giờ ra sửa tay: ngày của giờ vào (sửa tay, hoặc giờ vào thật nếu chỉ sửa giờ ra) + 1 ngày khi giờ ra không sau giờ vào
UPDATE attendances
SET override_check_out_day = override_check_in_day
    + IF(TIME_TO_SEC(override_check_out) <= TIME_TO_SEC(override_check_in), 1, 0)
WHERE override_check_out IS NOT NULL AND override_check_in IS NOT NULL;

UPDATE attendances
SET override_check_out_day = GREATEST(0, DATEDIFF(DATE(check_in), `date`))
    + IF(TIME_TO_SEC(override_check_out) <= TIME_TO_SEC(TIME(check_in)), 1, 0)
WHERE override_check_out IS NOT NULL AND override_check_in IS NULL AND check_in IS NOT NULL;
