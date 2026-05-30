ALTER TABLE salary_formulas
    ADD COLUMN income_vars    JSON NULL COMMENT 'Thu nhập thêm: {"VAR": {label, expression}}',
    ADD COLUMN allowance_vars JSON NULL COMMENT 'Trợ cấp: {"VAR": {label, expression}}';
