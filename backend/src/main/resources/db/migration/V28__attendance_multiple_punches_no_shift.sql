-- Chấm công không theo ca (V25): mỗi cặp vào / ra là một dòng riêng, nhiều dòng trong ngày.
-- punch_no = thứ tự lượt (0, 1, 2…) của các dòng không gắn ca; dòng gắn ca luôn 0 và vẫn khoá theo phân ca.
ALTER TABLE attendances
    ADD COLUMN punch_no INT NOT NULL DEFAULT 0;

ALTER TABLE attendances
    DROP INDEX uq_attendance_slot,
    DROP COLUMN slot_key,
    ADD COLUMN slot_key BIGINT GENERATED ALWAYS AS
        (IF(deleted, NULL, IFNULL(shift_assignment_id, -punch_no))) VIRTUAL,
    ADD UNIQUE KEY uq_attendance_slot (employee_id, date, slot_key);
