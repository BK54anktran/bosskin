-- =============================================
-- V32: Allow cancelling old profile edit requests
-- =============================================

ALTER TABLE profile_edit_requests
    MODIFY COLUMN status ENUM('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED') NOT NULL DEFAULT 'PENDING';
