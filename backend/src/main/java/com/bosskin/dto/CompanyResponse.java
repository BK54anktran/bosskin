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
    private boolean selfAttendanceEnabled;
    private long   employeeCount;
    private String adminEmail;
    private LocalDateTime createdAt;
}
