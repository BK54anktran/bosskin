package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/** Yêu cầu dùng thử từ trang giới thiệu (V12). Không thuộc công ty; system admin xử lý. */
@Entity
@Table(name = "trial_requests")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TrialRequest extends BaseEntity {

    public enum Status { NEW, CONTACTED, TRIAL, REJECTED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "full_name", nullable = false, length = 100)
    private String fullName;

    @Column(name = "company_name", nullable = false, length = 150)
    private String companyName;

    @Column(name = "phone", nullable = false, length = 30)
    private String phone;

    @Column(name = "email", length = 150)
    private String email;

    @Column(name = "company_size", length = 30)
    private String companySize;

    @Column(name = "need", length = 1000)
    private String need;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    @Builder.Default
    private Status status = Status.NEW;

    @Column(name = "admin_note", length = 1000)
    private String adminNote;

    @Column(name = "source", length = 200)
    private String source;

    @Column(name = "ip", length = 64)
    private String ip;

    @Column(name = "handled_by", length = 150)
    private String handledBy;

    @Column(name = "handled_at")
    private LocalDateTime handledAt;
}
