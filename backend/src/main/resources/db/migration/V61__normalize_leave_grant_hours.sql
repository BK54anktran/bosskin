-- Quy đổi grant_hours >= hours_per_day thành grant_days
UPDATE leave_grants g
JOIN companies c ON c.id = g.company_id
SET
    g.grant_days = COALESCE(g.grant_days, 0) + FLOOR(g.grant_hours / c.leave_hours_per_day),
    g.grant_hours = g.grant_hours - FLOOR(g.grant_hours / c.leave_hours_per_day) * c.leave_hours_per_day
WHERE g.grant_hours IS NOT NULL
  AND c.leave_hours_per_day > 0
  AND g.grant_hours >= c.leave_hours_per_day;

-- Quy đổi used_hours >= hours_per_day thành used_days
UPDATE leave_grants g
JOIN companies c ON c.id = g.company_id
SET
    g.used_days = COALESCE(g.used_days, 0) + FLOOR(g.used_hours / c.leave_hours_per_day),
    g.used_hours = g.used_hours - FLOOR(g.used_hours / c.leave_hours_per_day) * c.leave_hours_per_day
WHERE g.used_hours IS NOT NULL
  AND c.leave_hours_per_day > 0
  AND g.used_hours >= c.leave_hours_per_day;
