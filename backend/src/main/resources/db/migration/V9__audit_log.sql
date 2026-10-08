-- Bước 2 — nhật ký thao tác: ai làm gì, lúc nào, trên dữ liệu nào (sửa/duyệt công, lương, quyền, impersonate…).
-- Chỉ ghi thêm, không sửa/xoá. company_id NULL = thao tác cấp hệ thống (system admin).
CREATE TABLE `audit_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint DEFAULT NULL,
  `actor_user_id` bigint DEFAULT NULL,
  `actor_email` varchar(150) DEFAULT NULL,
  `actor_type` enum('USER','SYSTEM_ADMIN','IMPERSONATE','SYSTEM') NOT NULL,
  `action` varchar(50) NOT NULL,
  `entity_type` varchar(50) DEFAULT NULL,
  `entity_id` varchar(64) DEFAULT NULL,
  `summary` varchar(500) DEFAULT NULL,
  `detail` text DEFAULT NULL,
  `ip` varchar(64) DEFAULT NULL,
  `request_id` varchar(64) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_audit_company_time` (`company_id`, `created_at`),
  KEY `idx_audit_action` (`action`),
  KEY `idx_audit_entity` (`entity_type`, `entity_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO permissions (code, description, module, required_rule) VALUES
('AUDIT_VIEW', 'Xem nhật ký thao tác', 'COMPANY', NULL);

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code = 'AUDIT_VIEW'
WHERE r.name = 'Admin' AND r.deleted = 0;
