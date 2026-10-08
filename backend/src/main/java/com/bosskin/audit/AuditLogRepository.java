package com.bosskin.audit;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;

public interface AuditLogRepository extends JpaRepository<AuditLog, Long> {

    /** companyId null = mọi công ty (chỉ system admin). Các bộ lọc null = bỏ qua. */
    @Query("""
        SELECT a FROM AuditLog a
        WHERE (:companyId IS NULL OR a.companyId = :companyId)
          AND (:action IS NULL OR a.action = :action)
          AND (:entityType IS NULL OR a.entityType = :entityType)
          AND (:entityId IS NULL OR a.entityId = :entityId)
          AND (:actor IS NULL OR a.actorEmail LIKE CONCAT('%', :actor, '%'))
          AND (:from IS NULL OR a.createdAt >= :from)
          AND (:to IS NULL OR a.createdAt < :to)
        ORDER BY a.id DESC
        """)
    Page<AuditLog> search(@Param("companyId") Long companyId,
                          @Param("action") String action,
                          @Param("entityType") String entityType,
                          @Param("entityId") String entityId,
                          @Param("actor") String actor,
                          @Param("from") LocalDateTime from,
                          @Param("to") LocalDateTime to,
                          Pageable pageable);
}
