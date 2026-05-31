ALTER TABLE payrolls
    ADD COLUMN custom_formula JSON NULL COMMENT 'Inline formula snapshot, chỉ áp dụng cho payroll này';
