package com.bosskin.repository;

import com.bosskin.entity.FcmToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

public interface FcmTokenRepository extends JpaRepository<FcmToken, Long> {

    List<FcmToken> findByUserId(Long userId);

    Optional<FcmToken> findByToken(String token);

    boolean existsByUserId(Long userId);

    /** Gỡ token (đăng xuất trên thiết bị đó, hoặc FCM báo token hết hiệu lực). */
    @Transactional
    @Modifying
    @Query("DELETE FROM FcmToken t WHERE t.token = :token")
    int deleteByToken(@Param("token") String token);
}
