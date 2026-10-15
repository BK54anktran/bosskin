-- Tính năng theo công ty (core/CompanyFeatures): mịn hơn 7 gói của V24. Lưu danh sách tính năng TẮT, cách nhau dấu phẩy; NULL = bật hết.
-- Chuyển đúng từ disabled_modules: gói cũ tắt => mọi tính năng con của gói đó tắt; công ty đang bật hết giữ nguyên. Sau đó bỏ cột cũ.
ALTER TABLE companies ADD COLUMN disabled_features varchar(1000) DEFAULT NULL;

UPDATE companies SET disabled_features = NULLIF(CONCAT_WS(',',
  IF(FIND_IN_SET('ATTENDANCE', disabled_modules), 'ATT_SHEET,ATT_SELF,ATT_GEOFENCE,ATT_DEVICE,ATT_NOSHIFT,ATT_REQUEST', NULL),
  IF(FIND_IN_SET('SHIFT', disabled_modules), 'SHIFT_BASIC,SHIFT_ADVANCED,SHIFT_ROTATION,SHIFT_SWAP,SHIFT_REGISTRATION,SHIFT_REMINDER', NULL),
  IF(FIND_IN_SET('LEAVE', disabled_modules), 'LEAVE_BASIC,LEAVE_BALANCE,LEAVE_ACCRUAL', NULL),
  IF(FIND_IN_SET('PAYROLL', disabled_modules), 'PAY_BASIC,PAY_FORMULA,PAY_TAX_INS,PAY_DEPENDENT,PAY_EMPLOYER_COST', NULL),
  IF(FIND_IN_SET('CONTRACT', disabled_modules), 'HR_CONTRACT,HR_CONTRACT_ALERT', NULL),
  IF(FIND_IN_SET('DOCUMENT', disabled_modules), 'HR_DOCUMENT,HR_DOCUMENT_ALERT', NULL),
  IF(FIND_IN_SET('REPORT', disabled_modules), 'RPT_OVERVIEW,RPT_PAYROLL,RPT_INSURANCE', NULL)
), '')
WHERE disabled_modules IS NOT NULL;

-- Tính năng phụ thuộc phải tắt theo tính năng nó cần (vd. gói Tính lương tắt => báo cáo lương / bảo hiểm cũng tắt).
UPDATE companies SET disabled_features = CONCAT_WS(',', disabled_features, 'RPT_PAYROLL')
WHERE FIND_IN_SET('PAY_BASIC', disabled_features) AND NOT FIND_IN_SET('RPT_PAYROLL', disabled_features);
UPDATE companies SET disabled_features = CONCAT_WS(',', disabled_features, 'RPT_INSURANCE')
WHERE FIND_IN_SET('PAY_DEPENDENT', disabled_features) AND NOT FIND_IN_SET('RPT_INSURANCE', disabled_features);

ALTER TABLE companies DROP COLUMN disabled_modules;
