-- Bước J: ngày lễ theo năm + lịch làm việc tuần theo công ty / phòng ban.
-- holidays.company_id NULL = mẫu hệ thống (system admin sửa ở /admin/holidays). Công ty chưa chỉnh năm nào thì dùng mẫu
-- của năm đó; lần chỉnh đầu tiên chép mẫu năm đó sang công ty (copy-on-write), từ đó chỉ dùng danh sách của công ty.
--   HOLIDAY       ngày lễ / Tết (paid = hưởng lương)
--   COMPENSATORY  nghỉ bù khi lễ trùng ngày nghỉ tuần (thường có lương)
--   SWAP_WORKDAY  ngày làm bù khi hoán đổi (ngày nghỉ tuần thành ngày làm cả ngày)
-- Ngày nghỉ hoán đổi nhập là HOLIDAY paid = false.
CREATE TABLE holidays (
  id bigint NOT NULL AUTO_INCREMENT,
  company_id bigint DEFAULT NULL,
  holiday_date date NOT NULL,
  name varchar(150) NOT NULL,
  type enum('HOLIDAY','COMPENSATORY','SWAP_WORKDAY') NOT NULL DEFAULT 'HOLIDAY',
  paid tinyint(1) NOT NULL DEFAULT 1,
  deleted tinyint(1) NOT NULL DEFAULT 0,
  created_at datetime(6) NOT NULL,
  updated_at datetime(6) NOT NULL,
  date_key date GENERATED ALWAYS AS (IF(deleted, NULL, holiday_date)) VIRTUAL,
  company_key bigint GENERATED ALWAYS AS (IFNULL(company_id, 0)) VIRTUAL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_holiday_company_date (company_key, date_key),
  KEY idx_holiday_company_date (company_id, holiday_date),
  CONSTRAINT fk_holiday_company FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Mẫu 2026–2027 theo Bộ luật Lao động 2019 Điều 112 (+ 24/11 từ 01/07/2026 theo NQ 28/2026/QH16).
-- Tết Âm lịch 5 ngày lấy ngày cuối năm cũ + mùng 1–4; ngày liền kề Quốc khánh và nghỉ bù / hoán đổi
-- theo thông báo hằng năm của Bộ LĐ-TB&XH — system admin chỉnh khi có thông báo.
INSERT INTO holidays (company_id, holiday_date, name, type, paid, created_at, updated_at) VALUES
(NULL, '2026-01-01', 'Tết Dương lịch', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2026-02-16', 'Tết Âm lịch (30 Tết)', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2026-02-17', 'Tết Âm lịch (Mùng 1)', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2026-02-18', 'Tết Âm lịch (Mùng 2)', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2026-02-19', 'Tết Âm lịch (Mùng 3)', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2026-02-20', 'Tết Âm lịch (Mùng 4)', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2026-04-26', 'Giỗ Tổ Hùng Vương (10/3 ÂL)', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2026-04-30', 'Ngày Chiến thắng', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2026-05-01', 'Quốc tế Lao động', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2026-09-01', 'Quốc khánh (ngày liền kề)', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2026-09-02', 'Quốc khánh', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2026-11-24', 'Ngày Văn hoá Việt Nam', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2027-01-01', 'Tết Dương lịch', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2027-02-05', 'Tết Âm lịch (30 Tết)', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2027-02-06', 'Tết Âm lịch (Mùng 1)', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2027-02-07', 'Tết Âm lịch (Mùng 2)', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2027-02-08', 'Tết Âm lịch (Mùng 3)', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2027-02-09', 'Tết Âm lịch (Mùng 4)', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2027-04-16', 'Giỗ Tổ Hùng Vương (10/3 ÂL)', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2027-04-30', 'Ngày Chiến thắng', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2027-05-01', 'Quốc tế Lao động', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2027-09-02', 'Quốc khánh', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2027-09-03', 'Quốc khánh (ngày liền kề)', 'HOLIDAY', 1, NOW(6), NOW(6)),
(NULL, '2027-11-24', 'Ngày Văn hoá Việt Nam', 'HOLIDAY', 1, NOW(6), NOW(6));

-- Lịch tuần: week_pattern 7 ký tự T2→CN, F = cả ngày, H = nửa ngày, O = nghỉ.
-- Mỗi công ty tối đa 1 lịch is_default; chưa có thì dùng FFFFFOO. Phòng ban không gán lịch → lịch của phòng cha → mặc định.
CREATE TABLE work_calendars (
  id bigint NOT NULL AUTO_INCREMENT,
  company_id bigint NOT NULL,
  name varchar(100) NOT NULL,
  week_pattern varchar(7) NOT NULL DEFAULT 'FFFFFOO',
  is_default tinyint(1) NOT NULL DEFAULT 0,
  deleted tinyint(1) NOT NULL DEFAULT 0,
  created_at datetime(6) NOT NULL,
  updated_at datetime(6) NOT NULL,
  default_key tinyint GENERATED ALWAYS AS (IF(deleted = 0 AND is_default = 1, 1, NULL)) VIRTUAL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_work_calendar_default (company_id, default_key),
  CONSTRAINT fk_work_calendar_company FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE departments
  ADD COLUMN work_calendar_id bigint DEFAULT NULL,
  ADD CONSTRAINT fk_department_work_calendar FOREIGN KEY (work_calendar_id) REFERENCES work_calendars (id) ON DELETE SET NULL;

-- Công chuẩn kỳ lương: false = số cố định standard_work_days (như cũ), true = đếm theo lịch tuần + ngày lễ
ALTER TABLE companies ADD COLUMN standard_days_from_calendar tinyint(1) NOT NULL DEFAULT 0;

-- Công chuẩn có thể lẻ nửa ngày (T7 làm sáng)
ALTER TABLE payrolls MODIFY COLUMN standard_work_days decimal(5,2) DEFAULT NULL;

INSERT INTO permissions (code, description, module, required_rule) VALUES
('CALENDAR_VIEW', 'Xem ngày lễ và lịch làm việc', 'CALENDAR', NULL),
('CALENDAR_MANAGE', 'Sửa ngày lễ và lịch làm việc', 'CALENDAR', 'CALENDAR_VIEW');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code IN ('CALENDAR_VIEW', 'CALENDAR_MANAGE')
WHERE r.name = 'Admin' AND r.deleted = 0;
