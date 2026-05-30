-- Fix expression cho các biến khấu trừ: dùng PIT_VN() và công thức chuẩn thay vì GROSS * 0

UPDATE formula_variables
SET expression = 'BASE_RATE * SOCIAL_INS_RATE'
WHERE name = 'SOCIAL_INS';

UPDATE formula_variables
SET expression = 'BASE_RATE * HEALTH_INS_RATE'
WHERE name = 'HEALTH_INS';

UPDATE formula_variables
SET expression = 'BASE_RATE * UNEMPLOYMENT_RATE'
WHERE name = 'UNEMPLOYMENT_INS';

-- PIT = thuế TNCN lũy tiến, tính trên thu nhập chịu thuế (sau khi trừ bảo hiểm và giảm trừ gia cảnh 11tr)
UPDATE formula_variables
SET expression = 'PIT_VN(GROSS - SOCIAL_INS - HEALTH_INS - UNEMPLOYMENT_INS - 11000000)'
WHERE name = 'PIT';
