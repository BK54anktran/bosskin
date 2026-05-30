-- Chuyển 3 tỷ lệ bảo hiểm từ hằng số hệ thống sang global variable cho mỗi company.
-- INSERT IGNORE để idempotent nếu đã có (e.g. dev env chạy lại).
INSERT IGNORE INTO formula_variables (company_id, name, label, expression)
SELECT id, 'SOCIAL_INS_RATE', 'Tỷ lệ BHXH', '0.08'
FROM companies;

INSERT IGNORE INTO formula_variables (company_id, name, label, expression)
SELECT id, 'HEALTH_INS_RATE', 'Tỷ lệ BHYT', '0.015'
FROM companies;

INSERT IGNORE INTO formula_variables (company_id, name, label, expression)
SELECT id, 'UNEMPLOYMENT_RATE', 'Tỷ lệ BHTN', '0.01'
FROM companies;
