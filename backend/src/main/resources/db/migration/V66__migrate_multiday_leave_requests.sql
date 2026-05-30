-- Với mỗi đơn phép nhiều ngày (fromDate != toDate, parent_id IS NULL, không phải HOUR_RANGE),
-- tạo đơn con cho từng ngày rồi set parent_id của các con trỏ về đơn cha.
-- Lưu ý: requestedAmount của đơn con = requestedAmount / số ngày (rounded).
-- Grant balance KHÔNG thay đổi vì phép đã trừ khi tạo đơn gốc.

INSERT INTO leave_requests (
    company_id, employee_id, leave_type_id, mode,
    from_date, to_date, from_time, to_time,
    requested_amount, status, applied, reason, admin_note,
    processed_by, processed_at, parent_id,
    created_at, updated_at
)
SELECT
    p.company_id,
    p.employee_id,
    p.leave_type_id,
    p.mode,
    d.day_date,
    d.day_date,
    p.from_time,
    p.to_time,
    ROUND(p.requested_amount / (DATEDIFF(p.to_date, p.from_date) + 1), 2),
    p.status,
    p.applied,
    p.reason,
    p.admin_note,
    p.processed_by,
    p.processed_at,
    p.id,
    p.created_at,
    p.updated_at
FROM leave_requests p
JOIN (
    -- Generate dates between from_date and to_date using a numbers table trick
    SELECT
        lr.id AS parent_id,
        DATE_ADD(lr.from_date, INTERVAL n.n DAY) AS day_date
    FROM leave_requests lr
    JOIN (
        SELECT 0 n UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
        UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9
        UNION SELECT 10 UNION SELECT 11 UNION SELECT 12 UNION SELECT 13 UNION SELECT 14
        UNION SELECT 15 UNION SELECT 16 UNION SELECT 17 UNION SELECT 18 UNION SELECT 19
        UNION SELECT 20 UNION SELECT 21 UNION SELECT 22 UNION SELECT 23 UNION SELECT 24
        UNION SELECT 25 UNION SELECT 26 UNION SELECT 27 UNION SELECT 28 UNION SELECT 29
        UNION SELECT 30
    ) n ON DATE_ADD(lr.from_date, INTERVAL n.n DAY) <= lr.to_date
    WHERE lr.from_date != lr.to_date
      AND lr.mode = 'DAY_RANGE'
      AND lr.parent_id IS NULL
) d ON p.id = d.parent_id;
