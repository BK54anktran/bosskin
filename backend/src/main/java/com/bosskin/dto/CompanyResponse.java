package com.bosskin.dto;

import lombok.*;

import java.time.LocalDateTime;

@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class CompanyResponse {
    private Long   id;
    private String name;
    private String code;
    private String domain;
    private String address;
    private String phone;
    private String email;
    private boolean active;
    /** Bước C: bắt buộc 2FA với quản trị công ty. */
    private boolean requireAdmin2fa;
    private boolean selfAttendanceEnabled;
    /** V24 (tương thích): gói chức năng đang bật. */
    private java.util.List<String> modules;
    /** V26: tính năng đang bật. */
    private java.util.List<String> features;
    private long   employeeCount;
    private String adminEmail;
    private LocalDateTime createdAt;
}
