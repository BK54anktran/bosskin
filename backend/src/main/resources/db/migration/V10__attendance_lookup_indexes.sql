-- Duyệt / tính công theo (nhân viên, ngày): index ghép cho các truy vấn tra theo NV + ngày.
-- Đo thử duyệt hàng loạt 300 NV × 22 ngày (6.600 dòng), mỗi dòng ~10 truy vấn tra theo NV + ngày.
CREATE INDEX idx_assign_employee_date ON shift_assignments (employee_id, work_date);
CREATE INDEX idx_attendance_request_employee_date ON attendance_requests (employee_id, request_date);
CREATE INDEX idx_leave_req_employee_dates ON leave_requests (employee_id, from_date, to_date);
