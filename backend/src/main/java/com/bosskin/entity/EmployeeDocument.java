package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Bước N (V18) — tài liệu gắn với nhân viên. File không có URL công khai: {@code fileKey} là khoá trong kho riêng tư,
 * chỉ trả link ký tạm. PENDING = NV tự gửi, chờ HR duyệt.
 */
@Entity
@Table(name = "employee_documents")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class EmployeeDocument extends BaseEntity {

    public enum Status { PENDING, APPROVED, REJECTED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "company_id", nullable = false)
    private Long companyId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "document_type_id", nullable = false)
    private DocumentType documentType;

    @Column(length = 200)
    private String title;

    @Column(name = "file_key", nullable = false, length = 300)
    private String fileKey;

    @Column(name = "file_name", nullable = false, length = 255)
    private String fileName;

    @Column(name = "content_type", nullable = false, length = 100)
    private String contentType;

    @Column(name = "file_size", nullable = false)
    private long fileSize;

    @Column(name = "issued_on")
    private LocalDate issuedOn;

    @Column(name = "expires_on")
    private LocalDate expiresOn;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "contract_id")
    private LaborContract contract;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private Status status = Status.APPROVED;

    @Column(name = "review_note", length = 500)
    private String reviewNote;

    @Column(name = "reviewed_by")
    private Long reviewedBy;

    @Column(name = "reviewed_at")
    private LocalDateTime reviewedAt;

    @Column(length = 500)
    private String note;

    @Column(name = "uploaded_by")
    private Long uploadedBy;

    @Column(nullable = false)
    @Builder.Default
    private boolean deleted = false;

    /** Còn hiệu lực ở ngày {@code d}: đã duyệt và chưa hết hạn. */
    public boolean validOn(LocalDate d) {
        return status == Status.APPROVED && (expiresOn == null || !expiresOn.isBefore(d));
    }
}
