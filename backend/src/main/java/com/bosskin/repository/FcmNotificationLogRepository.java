package com.bosskin.repository;

import com.bosskin.entity.FcmNotificationLog;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FcmNotificationLogRepository extends JpaRepository<FcmNotificationLog, Long> {
}
