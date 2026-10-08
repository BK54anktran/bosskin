-- =====================================================================
-- V3 · Nghỉ phép (Mốc 3a)
--  * leave_types.requires_balance: loại phép có trừ quỹ phép hay không (L8).
--    Nghỉ không lương, ốm (BHXH chi trả)… không trừ quỹ nên không bị chặn khi hết phép.
--  * leave_grants.version: khoá lạc quan, chặn 2 đơn song song vượt số dư (L17).
-- =====================================================================
ALTER TABLE leave_types
    ADD COLUMN requires_balance TINYINT(1) NOT NULL DEFAULT 1 AFTER is_paid;

-- Mặc định: loại không lương thì không trừ quỹ phép
UPDATE leave_types SET requires_balance = 0 WHERE is_paid = 0;

ALTER TABLE leave_grants
    ADD COLUMN version BIGINT NOT NULL DEFAULT 0;
