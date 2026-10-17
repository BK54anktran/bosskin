-- V33: thông báo dùng chung giữa các thiết bị của một tài khoản.
--  * fcm_tokens: nhiều thiết bị / tài khoản (trước chỉ giữ token của máy đăng nhập sau cùng trong users.fcm_token) — một token chỉ thuộc một tài khoản.
--  * user_notifications: hộp thư thông báo lưu ở máy chủ (trước nằm riêng trong bộ nhớ từng máy).
--  * users.notif_late_alert / notif_early_leave_alert: quản lý nhận báo nhân viên đi trễ / về sớm.
CREATE TABLE `fcm_tokens` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `token` varchar(512) NOT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_fcm_tokens_token` (`token`),
  KEY `idx_fcm_tokens_user` (`user_id`),
  CONSTRAINT `fk_fcm_tokens_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `fcm_tokens` (`user_id`, `token`) SELECT `id`, `fcm_token` FROM `users` WHERE `fcm_token` IS NOT NULL AND `fcm_token` <> '';
ALTER TABLE `users` DROP COLUMN `fcm_token`;

CREATE TABLE `user_notifications` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `type` varchar(40) NOT NULL,
  `title` varchar(200) NOT NULL,
  `body` varchar(1000) NOT NULL,
  `data` varchar(1000) DEFAULT NULL COMMENT 'JSON {khoá: giá trị} đi kèm thông báo (ngày công, loại đơn…)',
  `created_at` datetime(6) NOT NULL,
  `read_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_user_notifications_user` (`user_id`, `id`),
  CONSTRAINT `fk_user_notifications_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE `users`
  ADD COLUMN `notif_late_alert` tinyint(1) NOT NULL DEFAULT 0 AFTER `check_in_out_notif_minutes`,
  ADD COLUMN `notif_early_leave_alert` tinyint(1) NOT NULL DEFAULT 0 AFTER `notif_late_alert`;
