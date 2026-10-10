-- Bước K: lịch sử công tác (phòng ban / chức vụ / bậc lương / quản lý theo ngày hiệu lực) + quản lý trực tiếp
-- + chế độ duyệt "quản lý trực tiếp trước rồi HR".
--
-- Mỗi dòng employee_job_histories là ảnh chụp đủ 4 thông tin áp dụng từ effective_from. Bản hiện hành của nhân viên
-- = dòng mới nhất có effective_from <= hôm nay; employees.* giữ bản hiện hành (đồng bộ khi ghi và mỗi sáng).
-- Dòng tương lai chỉ áp dụng khi tới ngày (applied = 0 cho tới lúc đó).
CREATE TABLE employee_job_histories (
  id bigint NOT NULL AUTO_INCREMENT,
  company_id bigint NOT NULL,
  employee_id bigint NOT NULL,
  effective_from date NOT NULL,
  change_type enum('HIRE','TRANSFER','PROMOTION','SALARY_CHANGE','MANAGER_CHANGE','OTHER') NOT NULL DEFAULT 'OTHER',
  department_id bigint NOT NULL,
  position_id bigint DEFAULT NULL,
  salary_grade_id bigint DEFAULT NULL,
  manager_id bigint DEFAULT NULL,
  note varchar(500) DEFAULT NULL,
  applied tinyint(1) NOT NULL DEFAULT 0,
  created_by bigint DEFAULT NULL,
  deleted tinyint(1) NOT NULL DEFAULT 0,
  created_at datetime(6) NOT NULL,
  updated_at datetime(6) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_job_history_employee (employee_id, effective_from),
  KEY idx_job_history_due (applied, effective_from),
  CONSTRAINT fk_job_history_company FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE,
  CONSTRAINT fk_job_history_employee FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
  CONSTRAINT fk_job_history_department FOREIGN KEY (department_id) REFERENCES departments (id),
  CONSTRAINT fk_job_history_position FOREIGN KEY (position_id) REFERENCES positions (id) ON DELETE SET NULL,
  CONSTRAINT fk_job_history_grade FOREIGN KEY (salary_grade_id) REFERENCES salary_grades (id) ON DELETE SET NULL,
  CONSTRAINT fk_job_history_manager FOREIGN KEY (manager_id) REFERENCES employees (id) ON DELETE SET NULL,
  CONSTRAINT fk_job_history_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Quản lý trực tiếp (bản hiện hành); không cho vòng lặp — kiểm ở JobHistoryService
ALTER TABLE employees
  ADD COLUMN manager_id bigint DEFAULT NULL,
  ADD KEY idx_employee_manager (manager_id),
  ADD CONSTRAINT fk_employee_manager FOREIGN KEY (manager_id) REFERENCES employees (id) ON DELETE SET NULL;

-- Bản ghi đầu tiên từ dữ liệu hiện có (ngày vào làm)
INSERT INTO employee_job_histories (company_id, employee_id, effective_from, change_type, department_id, position_id,
                                    salary_grade_id, manager_id, note, applied, created_at, updated_at)
SELECT company_id, id, join_date, 'HIRE', department_id, position_id, salary_grade_id, NULL, NULL, 1, NOW(6), NOW(6)
FROM employees;

-- PERMISSION = như cũ (người có quyền duyệt + phạm vi); MANAGER_THEN_HR = quản lý trực tiếp duyệt trước, rồi HR duyệt
ALTER TABLE companies ADD COLUMN approval_mode varchar(20) NOT NULL DEFAULT 'PERMISSION';

-- Bước quản lý duyệt của từng loại đơn
ALTER TABLE leave_requests
  ADD COLUMN manager_approved_by bigint DEFAULT NULL,
  ADD COLUMN manager_approved_at datetime(6) DEFAULT NULL,
  ADD COLUMN manager_note varchar(500) DEFAULT NULL,
  ADD CONSTRAINT fk_leave_req_manager_approved_by FOREIGN KEY (manager_approved_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE attendance_requests
  ADD COLUMN manager_approved_by bigint DEFAULT NULL,
  ADD COLUMN manager_approved_at datetime(6) DEFAULT NULL,
  ADD COLUMN manager_note varchar(500) DEFAULT NULL,
  ADD CONSTRAINT fk_att_req_manager_approved_by FOREIGN KEY (manager_approved_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE shift_swap_requests
  ADD COLUMN manager_approved_by bigint DEFAULT NULL,
  ADD COLUMN manager_approved_at datetime(6) DEFAULT NULL,
  ADD COLUMN manager_note varchar(500) DEFAULT NULL,
  ADD CONSTRAINT fk_swap_req_manager_approved_by FOREIGN KEY (manager_approved_by) REFERENCES users (id) ON DELETE SET NULL;

-- Phiếu lương lưu phòng ban hiệu lực ở ngày cuối kỳ (NV chuyển phòng giữa kỳ vẫn đúng khi xem lại)
ALTER TABLE payrolls
  ADD COLUMN department_id bigint DEFAULT NULL,
  ADD COLUMN department_name varchar(255) DEFAULT NULL;
