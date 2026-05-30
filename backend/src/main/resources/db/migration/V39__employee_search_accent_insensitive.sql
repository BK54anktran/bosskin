-- Make employee search accent-insensitive and case-insensitive at DB layer.
-- This affects server-side search endpoints using employee name/email/code.

ALTER TABLE employees
    MODIFY COLUMN full_name VARCHAR(100)
        CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
    MODIFY COLUMN email VARCHAR(100)
        CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
    MODIFY COLUMN employee_code VARCHAR(20)
        CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL;

