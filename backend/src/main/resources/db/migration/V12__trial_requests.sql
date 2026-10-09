-- Yêu cầu dùng thử gửi từ trang giới thiệu (landing/). Không thuộc công ty nào; chỉ system admin xem/xử lý.
CREATE TABLE `trial_requests` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `full_name` varchar(100) NOT NULL,
  `company_name` varchar(150) NOT NULL,
  `phone` varchar(30) NOT NULL,
  `email` varchar(150) DEFAULT NULL,
  `company_size` varchar(30) DEFAULT NULL,
  `need` varchar(1000) DEFAULT NULL,
  `status` enum('NEW','CONTACTED','TRIAL','REJECTED') NOT NULL DEFAULT 'NEW',
  `admin_note` varchar(1000) DEFAULT NULL,
  `source` varchar(200) DEFAULT NULL,
  `ip` varchar(64) DEFAULT NULL,
  `handled_by` varchar(150) DEFAULT NULL,
  `handled_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_trial_status_time` (`status`, `created_at`),
  KEY `idx_trial_phone_time` (`phone`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
