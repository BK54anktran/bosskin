package com.bosskin.repository;

import com.bosskin.entity.UserNotification;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface UserNotificationRepository extends JpaRepository<UserNotification, Long> {

    List<UserNotification> findByUserIdOrderByIdDesc(Long userId, Pageable page);

    Optional<UserNotification> findByIdAndUserId(Long id, Long userId);

    long countByUserIdAndReadAtIsNull(Long userId);

    @Transactional
    @Modifying
    @Query("UPDATE UserNotification n SET n.readAt = :at WHERE n.userId = :userId AND n.readAt IS NULL")
    int markAllRead(@Param("userId") Long userId, @Param("at") LocalDateTime at);

    @Transactional
    @Modifying
    @Query("DELETE FROM UserNotification n WHERE n.userId = :userId")
    int deleteAllByUser(@Param("userId") Long userId);

    @Transactional
    @Modifying
    @Query("DELETE FROM UserNotification n WHERE n.createdAt < :before")
    int deleteOlderThan(@Param("before") LocalDateTime before);
}
