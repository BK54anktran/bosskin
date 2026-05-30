-- Thêm cột show_in_formula: nếu false thì biến vẫn được resolve nhưng không hiện trong chip picker
ALTER TABLE formula_variables
    ADD COLUMN show_in_formula TINYINT(1) NOT NULL DEFAULT 1;

-- Seed 4 biến khấu trừ (ẩn khỏi chip picker mặc định, user có thể bật lại)
INSERT IGNORE INTO formula_variables (company_id, name, label, expression, show_in_formula)
SELECT id, 'SOCIAL_INS', 'BHXH đã tính', 'BASE_RATE * SOCIAL_INS_RATE', 0
FROM companies;

INSERT IGNORE INTO formula_variables (company_id, name, label, expression, show_in_formula)
SELECT id, 'HEALTH_INS', 'BHYT đã tính', 'BASE_RATE * HEALTH_INS_RATE', 0
FROM companies;

INSERT IGNORE INTO formula_variables (company_id, name, label, expression, show_in_formula)
SELECT id, 'UNEMPLOYMENT_INS', 'BHTN đã tính', 'BASE_RATE * UNEMPLOYMENT_RATE', 0
FROM companies;

INSERT IGNORE INTO formula_variables (company_id, name, label, expression, show_in_formula)
SELECT id, 'PIT', 'Thuế TNCN đã tính', 'GROSS * 0', 0
FROM companies;
