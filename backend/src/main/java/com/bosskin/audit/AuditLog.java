package com.bosskin.audit;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/** Bước 2 — một dòng nhật ký thao tác (chỉ ghi thêm). */
@Entity
@Table(name = "audit_logs")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AuditLog {

    public enum ActorType { USER, SYSTEM_ADMIN, IMPERSONATE, SYSTEM }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "company_id")
    private Long companyId;

    @Column(name = "actor_user_id")
    private Long actorUserId;

    @Column(name = "actor_email", length = 150)
    private String actorEmail;

    @Enumerated(EnumType.STRING)
    @Column(name = "actor_type", nullable = false)
    private ActorType actorType;

    @Column(name = "action", nullable = false, length = 50)
    private String action;

    @Column(name = "entity_type", length = 50)
    private String entityType;

    @Column(name = "entity_id", length = 64)
    private String entityId;

    @Column(name = "summary", length = 500)
    private String summary;

    @Column(name = "detail", columnDefinition = "text")
    private String detail;

    @Column(name = "ip", length = 64)
    private String ip;

    @Column(name = "request_id", length = 64)
    private String requestId;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;
}
