ALTER TABLE salary_formulas
    ADD COLUMN custom_vars JSON NULL COMMENT 'Private variables: {"VAR_NAME": "expression", ...}';
