-- Allow multiple shift assignments per employee per day (max 2, enforced in service)
ALTER TABLE shift_assignments DROP INDEX uk_emp_date;
