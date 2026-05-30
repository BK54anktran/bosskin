ALTER TABLE payrolls
    ADD COLUMN income_entries    JSON NULL COMMENT 'Thu nhập thêm snapshot: {"VAR": {label, amount}}',
    ADD COLUMN allowance_entries JSON NULL COMMENT 'Trợ cấp snapshot: {"VAR": {label, amount}}';
