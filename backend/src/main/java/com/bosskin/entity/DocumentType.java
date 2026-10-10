package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

/** Bước N (V18) — loại tài liệu nhân sự do công ty cấu hình; mã duy nhất trong công ty (cột sinh {@code code_key}). */
@Entity
@Table(name = "document_types")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class DocumentType extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "company_id", nullable = false)
    private Long companyId;

    @Column(nullable = false, length = 30)
    private String code;

    @Column(nullable = false, length = 150)
    private String name;

    /** NV nào cũng phải có (danh sách "thiếu tài liệu bắt buộc"). */
    @Column(nullable = false)
    private boolean required;

    /** Có ngày hết hạn (bắt buộc nhập, có cảnh báo sắp hết hạn). */
    @Column(name = "has_expiry", nullable = false)
    private boolean hasExpiry;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    @Column(nullable = false)
    @Builder.Default
    private boolean deleted = false;
}
