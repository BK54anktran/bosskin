ALTER TABLE companies
    ADD COLUMN check_in_tolerance_minutes INTEGER NULL,
    ADD COLUMN check_out_tolerance_minutes INTEGER NULL,
    ADD COLUMN rounding_check_in_minutes INTEGER NULL,
    ADD COLUMN rounding_check_out_minutes INTEGER NULL,
    ADD COLUMN rounding_work_minutes INTEGER NULL;

ALTER TABLE departments
    ADD COLUMN check_in_tolerance_minutes INTEGER NULL,
    ADD COLUMN check_out_tolerance_minutes INTEGER NULL,
    ADD COLUMN rounding_check_in_minutes INTEGER NULL,
    ADD COLUMN rounding_check_out_minutes INTEGER NULL,
    ADD COLUMN rounding_work_minutes INTEGER NULL;
