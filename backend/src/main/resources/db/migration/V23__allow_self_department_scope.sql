-- Allow special scope markers such as -1 ("self only") in department-scope tables.
-- Existing rows remain valid; the foreign key is removed so the application can store
-- a reserved sentinel without colliding with department IDs.

ALTER TABLE user_permission_dept_scopes
    DROP FOREIGN KEY fk_upds_dept;

ALTER TABLE role_permission_dept_scopes
    DROP FOREIGN KEY fk_rpds_dept;
