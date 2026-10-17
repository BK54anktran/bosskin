-- Chức vụ chung: chức vụ không thuộc phòng ban nào (department_id NULL) dùng được ở mọi phòng ban của công ty
-- (vd. Quản lý, Nhân viên ở chuỗi cửa hàng). Chức vụ cần biết công ty trực tiếp nên thêm company_id (trước suy ra từ phòng ban).
ALTER TABLE positions ADD COLUMN company_id BIGINT NULL AFTER department_id;
UPDATE positions p JOIN departments d ON d.id = p.department_id SET p.company_id = d.company_id;
ALTER TABLE positions
    MODIFY COLUMN company_id BIGINT NOT NULL,
    MODIFY COLUMN department_id BIGINT NULL,
    ADD CONSTRAINT fk_position_company FOREIGN KEY (company_id) REFERENCES companies (id),
    DROP INDEX uq_position_department_code,
    ADD UNIQUE KEY uq_position_company_code (company_id, code_key);
