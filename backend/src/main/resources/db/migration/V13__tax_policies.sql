-- Bước I: thông số thuế TNCN / bảo hiểm theo ngày hiệu lực (thay hằng số trong PayrollService / FormulaEngine).
-- Kỳ lương dùng chính sách có effective_from <= ngày cuối kỳ gần nhất. System admin sửa ở /admin/tax-policies.
CREATE TABLE tax_policies (
  id bigint NOT NULL AUTO_INCREMENT,
  effective_from date NOT NULL,
  personal_deduction decimal(15,2) NOT NULL COMMENT 'Giảm trừ bản thân / tháng',
  dependent_deduction decimal(15,2) NOT NULL COMMENT 'Giảm trừ mỗi người phụ thuộc / tháng',
  pit_brackets varchar(1000) NOT NULL COMMENT 'JSON [{"upTo":10000000,"rate":0.05},...,{"upTo":null,"rate":0.35}] theo tháng',
  reference_wage decimal(15,2) NOT NULL COMMENT 'Mức tham chiếu (= lương cơ sở) — trần BHXH/BHYT',
  insurance_cap_multiplier int NOT NULL DEFAULT 20,
  unemployment_cap_multiplier int NOT NULL DEFAULT 20,
  min_wage_region1 decimal(15,2) NOT NULL,
  min_wage_region2 decimal(15,2) NOT NULL,
  min_wage_region3 decimal(15,2) NOT NULL,
  min_wage_region4 decimal(15,2) NOT NULL,
  note varchar(500) DEFAULT NULL,
  updated_by varchar(150) DEFAULT NULL,
  created_at datetime(6) NOT NULL,
  updated_at datetime(6) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tax_policy_effective_from (effective_from)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO tax_policies (effective_from, personal_deduction, dependent_deduction, pit_brackets, reference_wage,
  insurance_cap_multiplier, unemployment_cap_multiplier, min_wage_region1, min_wage_region2, min_wage_region3, min_wage_region4,
  note, created_at, updated_at) VALUES
('2024-07-01', 11000000, 4400000,
 '[{"upTo":5000000,"rate":0.05},{"upTo":10000000,"rate":0.10},{"upTo":18000000,"rate":0.15},{"upTo":32000000,"rate":0.20},{"upTo":52000000,"rate":0.25},{"upTo":80000000,"rate":0.30},{"upTo":null,"rate":0.35}]',
 2340000, 20, 20, 4960000, 4410000, 3860000, 3450000,
 'NQ 954/2020/UBTVQH14; biểu 7 bậc Luật TNCN 2007; lương cơ sở NĐ 73/2024; lương tối thiểu vùng NĐ 74/2024', NOW(6), NOW(6)),
('2026-01-01', 15500000, 6200000,
 '[{"upTo":10000000,"rate":0.05},{"upTo":30000000,"rate":0.10},{"upTo":60000000,"rate":0.20},{"upTo":100000000,"rate":0.30},{"upTo":null,"rate":0.35}]',
 2340000, 20, 20, 5310000, 4730000, 4140000, 3700000,
 'NQ 110/2025/UBTVQH15; biểu 5 bậc Luật Thuế TNCN 109/2025/QH15; lương tối thiểu vùng NĐ 293/2025', NOW(6), NOW(6)),
('2026-07-01', 15500000, 6200000,
 '[{"upTo":10000000,"rate":0.05},{"upTo":30000000,"rate":0.10},{"upTo":60000000,"rate":0.20},{"upTo":100000000,"rate":0.30},{"upTo":null,"rate":0.35}]',
 2530000, 20, 20, 5310000, 4730000, 4140000, 3700000,
 'Lương cơ sở / mức tham chiếu 2.530.000 (NĐ 161/2026)', NOW(6), NOW(6));

-- Vùng lương tối thiểu của công ty (1–4) → trần đóng BHTN = 20 × lương tối thiểu vùng
ALTER TABLE companies ADD COLUMN min_wage_region int NOT NULL DEFAULT 1;

-- Snapshot trên phiếu lương: giảm trừ gia cảnh và lương đóng BH (sau trần) đã dùng
ALTER TABLE payrolls
  ADD COLUMN family_deduction decimal(15,2) DEFAULT NULL,
  ADD COLUMN insurance_base decimal(15,2) DEFAULT NULL;
