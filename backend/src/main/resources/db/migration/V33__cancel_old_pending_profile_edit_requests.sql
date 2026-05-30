-- =============================================
-- V33: Cancel legacy duplicate pending profile edit requests
-- =============================================

UPDATE profile_edit_requests per
JOIN (
    SELECT id
    FROM (
        SELECT
            id,
            ROW_NUMBER() OVER (
                PARTITION BY employee_id
                ORDER BY created_at DESC, id DESC
            ) AS rn
        FROM profile_edit_requests
        WHERE status = 'PENDING'
    ) ranked
    WHERE ranked.rn > 1
) old_pending ON old_pending.id = per.id
SET per.status = 'CANCELLED',
    per.admin_note = 'Đơn cũ được hủy tự động khi có yêu cầu mới',
    per.updated_at = NOW(6);
