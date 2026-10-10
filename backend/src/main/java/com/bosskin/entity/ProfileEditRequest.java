package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;

@Entity
@Table(name = "profile_edit_requests")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ProfileEditRequest extends BaseEntity {

    public enum Status { PENDING, APPROVED, REJECTED, CANCELLED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @Column(name = "full_name", length = 100)
    private String fullName;

    @Enumerated(EnumType.STRING)
    @Column(name = "gender")
    private Employee.Gender gender;

    @Column(name = "date_of_birth")
    private LocalDate dateOfBirth;

    @Column(name = "phone", length = 15)
    private String phone;

    @Column(name = "personal_email", length = 100)
    private String personalEmail;

    @Column(name = "avatar_url", length = 255)
    private String avatarUrl;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    @Builder.Default
    private Status status = Status.PENDING;

    @Column(name = "admin_note", columnDefinition = "TEXT")
    private String adminNote;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "processed_by")
    private User processedBy;

    @Column(name = "processed_at")
    private java.time.LocalDateTime processedAt;

    // D11: giá trị trên hồ sơ ngay trước khi duyệt (V19)
    @Column(name = "old_full_name", length = 100)
    private String oldFullName;

    @Enumerated(EnumType.STRING)
    @Column(name = "old_gender")
    private Employee.Gender oldGender;

    @Column(name = "old_date_of_birth")
    private LocalDate oldDateOfBirth;

    @Column(name = "old_phone", length = 15)
    private String oldPhone;

    @Column(name = "old_personal_email", length = 100)
    private String oldPersonalEmail;
}
