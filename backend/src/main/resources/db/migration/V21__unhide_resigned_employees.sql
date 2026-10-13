-- Sửa dữ liệu (13/10/2026): trước đây nút "Nghỉ việc" (DELETE /employees/{id}) xoá mềm nhân viên → người đã nghỉ biến mất
-- khỏi mọi danh sách, kể cả lọc "Nghỉ việc". Nút đó còn định ghi status INACTIVE + ngày nghỉ nhưng Hibernate bỏ phần cập nhật
-- khi xoá ngay sau đó, nên trong DB chỉ còn deleted = 1 (status vẫn ACTIVE). Dấu vết phân biệt với xoá qua nhập Excel:
-- nút cũ KHOÁ tài khoản đăng nhập (users.enabled = 0), thời điểm khoá = users.updated_at.
-- Nay nghỉ việc không xoá (POST /employees/{id}/resign). Migration hiện lại những người đó, không xoá gì:
--   deleted = 0, status = INACTIVE, leave_date = ngày khoá tài khoản (nếu chưa có); tài khoản vẫn khoá.
--   Bỏ qua dòng mà mã NV / email đã có người đang dùng trong công ty (unique code_key / email_key); nhiều dòng cũ trùng
--   mã hoặc email với nhau thì chỉ hiện dòng mới nhất. Người bị nút cũ ẩn mà không có tài khoản thì không phân biệt được
--   với xoá qua Excel → giữ nguyên.
-- Bảng dẫn xuất có DISTINCT để MySQL tạo bảng tạm, tránh lỗi 1093 khi UPDATE bảng có trong truy vấn con.
UPDATE employees e
JOIN (
    SELECT DISTINCT d.id
    FROM employees d
    JOIN users u ON u.employee_id = d.id AND u.enabled = 0 AND u.deleted = 0
    WHERE d.deleted = 1
      AND NOT EXISTS (SELECT 1 FROM employees a
                      WHERE a.deleted = 0 AND a.company_id = d.company_id
                        AND (a.employee_code = d.employee_code OR (d.email IS NOT NULL AND a.email = d.email)))
      AND NOT EXISTS (SELECT 1 FROM employees o JOIN users ou ON ou.employee_id = o.id AND ou.enabled = 0 AND ou.deleted = 0
                      WHERE o.deleted = 1 AND o.company_id = d.company_id AND o.id > d.id
                        AND (o.employee_code = d.employee_code OR (d.email IS NOT NULL AND o.email = d.email)))
) r ON r.id = e.id
JOIN users u ON u.employee_id = e.id
SET e.deleted = 0,
    e.status = 'INACTIVE',
    e.leave_date = COALESCE(e.leave_date, DATE(u.updated_at));
