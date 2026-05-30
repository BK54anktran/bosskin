-- Gán category và bật show_in_formula cho các biến bảo hiểm
UPDATE formula_variables SET category = 'Bảo hiểm', show_in_formula = 1
WHERE name IN ('SOCIAL_INS_RATE', 'HEALTH_INS_RATE', 'UNEMPLOYMENT_RATE',
               'SOCIAL_INS', 'HEALTH_INS', 'UNEMPLOYMENT_INS');

-- Gán category và bật show_in_formula cho biến thuế/khấu trừ
UPDATE formula_variables SET category = 'Khấu trừ', show_in_formula = 1
WHERE name = 'PIT';
