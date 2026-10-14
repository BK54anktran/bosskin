-- Xoá HẲN "Công ty test" (mã TEST, đuôi @test.com) do tools/demo/seed_test_company.py tạo, cùng toàn bộ dữ liệu của nó.
-- Không đụng công ty khác. Chạy lại seed_test_company.py sau đó để tạo mới.
--
-- CẢNH BÁO: xoá cứng, không hoàn tác. Sao lưu DB trước (runbook mục 5). Chỉ chạy khi chắc chắn muốn bỏ công ty TEST.
-- Cách chạy: mysql -h <host> -u <user> -p <tên DB> < tools/demo/clear_test_company.sql
--            (hoặc dán cả file vào khung SQL của công cụ quản trị DB). Lược đồ: V22.
-- Không xoá file tài liệu đã tải lên kho (S3 / thư mục local, đường dẫn company-<id>/...) — dọn tay nếu cần.
--
-- Khoá ngoại vẫn BẬT: sót bảng nào thì MySQL báo lỗi và không xoá dòng đó (an toàn hơn tắt kiểm tra).
-- Cả file trong một transaction: lỗi giữa chừng → đóng kết nối là huỷ hết.

SET @cid := (SELECT id FROM companies WHERE code = 'TEST' AND domain = 'test.com');
SELECT IFNULL(CONCAT('Xoá công ty TEST, id = ', @cid), 'Không có công ty TEST / test.com — không xoá gì') AS thong_bao;

START TRANSACTION;

-- 1. Gỡ các tham chiếu vòng trong công ty
UPDATE users        SET employee_id = NULL WHERE company_id = @cid;
UPDATE departments  SET manager_id = NULL, parent_id = NULL, work_calendar_id = NULL WHERE company_id = @cid;
UPDATE employees    SET manager_id = NULL WHERE company_id = @cid;
UPDATE roles        SET role_view_department_id = NULL WHERE company_id = @cid;
UPDATE leave_requests SET parent_id = NULL WHERE company_id = @cid;

-- 2. Chấm công, phép, ca
DELETE al FROM attendance_approve_leaves al JOIN attendances a ON a.id = al.attendance_id
  JOIN employees e ON e.id = a.employee_id WHERE e.company_id = @cid;
DELETE al FROM attendance_approve_leaves al JOIN leave_requests r ON r.id = al.leave_request_id WHERE r.company_id = @cid;
DELETE FROM leave_ledger_entries WHERE company_id = @cid;
DELETE FROM leave_requests WHERE company_id = @cid;
DELETE ar FROM attendance_requests ar JOIN employees e ON e.id = ar.employee_id WHERE e.company_id = @cid;
DELETE FROM shift_swap_requests WHERE company_id = @cid;
DELETE a FROM attendances a JOIN employees e ON e.id = a.employee_id WHERE e.company_id = @cid;
DELETE sa FROM shift_assignments sa JOIN employees e ON e.id = sa.employee_id WHERE e.company_id = @cid;
DELETE FROM shift_rotations WHERE company_id = @cid;
DELETE ds FROM department_shifts ds JOIN departments d ON d.id = ds.department_id WHERE d.company_id = @cid;
DELETE FROM attendance_period_locks WHERE company_id = @cid;
DELETE FROM leave_grants WHERE company_id = @cid;
DELETE FROM leave_accrual_rules WHERE company_id = @cid;

-- 3. Hồ sơ nhân viên, hợp đồng, lương
DELETE d FROM employee_documents d JOIN employees e ON e.id = d.employee_id WHERE e.company_id = @cid;
DELETE ca FROM contract_allowances ca JOIN labor_contracts c ON c.id = ca.contract_id WHERE c.company_id = @cid;
DELETE cp FROM contract_appendices cp JOIN labor_contracts c ON c.id = cp.contract_id WHERE c.company_id = @cid;
DELETE FROM labor_contracts WHERE company_id = @cid;
DELETE x FROM employee_dependents x JOIN employees e ON e.id = x.employee_id WHERE e.company_id = @cid;
DELETE x FROM employee_locations x JOIN employees e ON e.id = x.employee_id WHERE e.company_id = @cid;
DELETE FROM employee_job_histories WHERE company_id = @cid;
DELETE x FROM profile_edit_requests x JOIN employees e ON e.id = x.employee_id WHERE e.company_id = @cid;
DELETE x FROM salary_histories x JOIN employees e ON e.id = x.employee_id WHERE e.company_id = @cid;
DELETE x FROM payrolls x JOIN employees e ON e.id = x.employee_id WHERE e.company_id = @cid;

-- 4. Tài khoản
DELETE x FROM user_sessions x JOIN users u ON u.id = x.user_id WHERE u.company_id = @cid;
DELETE x FROM user_roles x JOIN users u ON u.id = x.user_id WHERE u.company_id = @cid;
DELETE x FROM user_permissions x JOIN users u ON u.id = x.user_id WHERE u.company_id = @cid;
DELETE x FROM user_permission_dept_scopes x JOIN users u ON u.id = x.user_id WHERE u.company_id = @cid;
DELETE x FROM fcm_notification_logs x JOIN users u ON u.id = x.user_id WHERE u.company_id = @cid;
DELETE FROM excel_history WHERE company_id = @cid;
DELETE FROM audit_logs WHERE company_id = @cid;
DELETE FROM employees WHERE company_id = @cid;
DELETE FROM users WHERE company_id = @cid;

-- 5. Danh mục của công ty
DELETE x FROM role_permission_dept_scopes x JOIN roles r ON r.id = x.role_id WHERE r.company_id = @cid;
DELETE x FROM role_permissions x JOIN roles r ON r.id = x.role_id WHERE r.company_id = @cid;
DELETE FROM roles WHERE company_id = @cid;
DELETE f FROM salary_formulas f JOIN salary_grades g ON g.id = f.salary_grade_id WHERE g.company_id = @cid;
DELETE FROM salary_grades WHERE company_id = @cid;
DELETE p FROM positions p JOIN departments d ON d.id = p.department_id WHERE d.company_id = @cid;
DELETE FROM document_types WHERE company_id = @cid;
DELETE FROM leave_types WHERE company_id = @cid;
DELETE FROM work_shifts WHERE company_id = @cid;
DELETE FROM formula_variables WHERE company_id = @cid;
DELETE FROM holidays WHERE company_id = @cid;
DELETE FROM employee_code_counters WHERE company_id = @cid;
DELETE FROM departments WHERE company_id = @cid;
DELETE FROM work_calendars WHERE company_id = @cid;
DELETE FROM companies WHERE id = @cid;

COMMIT;

SELECT IF(EXISTS (SELECT 1 FROM companies WHERE code = 'TEST'), 'CÒN công ty TEST — kiểm tra lỗi phía trên', 'Đã xoá xong công ty TEST')
  AS ket_qua;
