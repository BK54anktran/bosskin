package com.bosskin.repository;

import com.bosskin.entity.UserSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.time.LocalDateTime;
import java.util.Optional;

public interface UserSessionRepository extends JpaRepository<UserSession, Long> {

    Optional<UserSession> findByJti(String jti);

    @Modifying
    @Query("DELETE FROM UserSession s WHERE s.expiresAt < :now OR s.revoked = true")
    void cleanupExpiredAndRevoked(LocalDateTime now);

    @Modifying
    @Query("UPDATE UserSession s SET s.revoked = true WHERE s.user.id = :userId")
    int revokeAllByUserId(Long userId);
}
