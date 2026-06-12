package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

@Entity
@Table(name = "excel_history")
@EntityListeners(AuditingEntityListener.class)
@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class ExcelHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "company_id", nullable = false)
    private Long companyId;

    @Column(name = "user_id")
    private Long userId;

    /** EXPORT | IMPORT | REPORT */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private HistoryType type;

    /** universal | payroll | attendance | shift | ... */
    @Column(nullable = false, length = 50)
    private String module;

    @Column(nullable = false)
    private String filename;

    @Column(name = "file_url", length = 1024)
    private String fileUrl;

    @Column(name = "ok_count")
    private Integer okCount;

    @Column(name = "error_count")
    private Integer errorCount;

    @Column(name = "skip_count")
    private Integer skipCount;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    public enum HistoryType { EXPORT, IMPORT, REPORT }
}
