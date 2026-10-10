package com.bosskin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.*;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

/** Bước N — tài liệu nhân sự. */
public class DocumentDTO {

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class TypeResponse {
        private Long id;
        private String code;
        private String name;
        private boolean required;
        private boolean hasExpiry;
        private int sortOrder;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class TypeUpsert {
        @NotBlank @Size(max = 30) private String code;
        @NotBlank @Size(max = 150) private String name;
        private boolean required;
        private boolean hasExpiry;
        private Integer sortOrder;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class Response {
        private Long id;
        private Long employeeId;
        private String employeeCode;
        private String employeeName;
        private Long departmentId;
        private String departmentName;
        private Long typeId;
        private String typeCode;
        private String typeName;
        private String title;
        private String fileName;
        private String contentType;
        private long fileSize;
        private LocalDate issuedOn;
        private LocalDate expiresOn;
        /** Số ngày tới hạn (âm = đã hết hạn); null = không có hạn. */
        private Integer daysToExpiry;
        private Long contractId;
        private String contractNo;
        private String status;
        private String reviewNote;
        private String note;
        private LocalDateTime createdAt;
    }

    /** Sửa thông tin (không đổi file). */
    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class Update {
        private Long typeId;
        @Size(max = 200) private String title;
        private LocalDate issuedOn;
        private LocalDate expiresOn;
        private Long contractId;
        @Size(max = 500) private String note;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ReviewRequest {
        @Size(max = 500) private String note;
    }

    /** Link ký tạm để xem / tải; {@code url} bắt đầu bằng "/" là đường dẫn trên chính backend. */
    @Getter @AllArgsConstructor
    public static class Link {
        private String url;
        private Instant expiresAt;
        private String fileName;
    }

    /** NV còn thiếu tài liệu bắt buộc (chưa có bản đã duyệt còn hạn). */
    @Getter @Builder
    public static class Missing {
        private Long employeeId;
        private String employeeCode;
        private String employeeName;
        private String departmentName;
        private List<String> missingTypes;
    }
}
