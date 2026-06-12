-- Thêm cột module để phân biệt nguồn gốc file (universal, payroll, attendance, shift, ...)
ALTER TABLE excel_history
    ADD COLUMN module VARCHAR(50) NOT NULL DEFAULT 'universal' AFTER type,
    MODIFY COLUMN type ENUM('EXPORT','IMPORT','REPORT') NOT NULL;
