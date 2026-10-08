-- L13: sổ trừ/hoàn phép theo từng đơn. Mỗi lần trừ/hoàn ghi đúng phần đã đổi trên từng quỹ (leave_grants),
-- hoàn phép đảo ngược chính các dòng đã trừ thay vì đoán quỹ.
-- request_id = đơn gốc đã trừ phép (đơn lẻ, hoặc đơn cha của nhóm nhiều ngày).
CREATE TABLE `leave_ledger_entries` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `employee_id` bigint NOT NULL,
  `grant_id` bigint NOT NULL,
  `request_id` bigint NOT NULL,
  `kind` enum('DEDUCT','REFUND') NOT NULL,
  `days` decimal(10,4) NOT NULL DEFAULT '0.0000',
  `hours` decimal(10,4) NOT NULL DEFAULT '0.0000',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_ledger_request` (`request_id`),
  KEY `idx_ledger_employee` (`employee_id`),
  KEY `fk_ledger_grant` (`grant_id`),
  CONSTRAINT `fk_ledger_company` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `fk_ledger_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`),
  CONSTRAINT `fk_ledger_grant` FOREIGN KEY (`grant_id`) REFERENCES `leave_grants` (`id`),
  CONSTRAINT `fk_ledger_request` FOREIGN KEY (`request_id`) REFERENCES `leave_requests` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
