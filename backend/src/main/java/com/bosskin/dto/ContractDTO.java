package com.bosskin.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/** Bước L — hợp đồng lao động, phụ lục, phụ cấp. */
public class ContractDTO {

    @Data @Builder @NoArgsConstructor @AllArgsConstructor
    public static class Allowance {
        private Long id;
        /** A–Z, 0–9, _ — biến lương ALLOWANCE_<code>. */
        @NotBlank @Size(max = 30) private String code;
        @NotBlank @Size(max = 150) private String name;
        @NotNull private BigDecimal amount;
        private boolean insurable;
        @Builder.Default private boolean taxable = true;
    }

    @Data @Builder @NoArgsConstructor @AllArgsConstructor
    public static class AppendixResponse {
        private Long id;
        private String appendixNo;
        private LocalDate effectiveFrom;
        private BigDecimal baseSalary;
        private BigDecimal insuranceSalary;
        private String positionTitle;
        private boolean overridesAllowances;
        private String note;
        private List<Allowance> allowances;
    }

    @Data @Builder @NoArgsConstructor @AllArgsConstructor
    public static class Response {
        private Long id;
        private Long employeeId;
        private String employeeCode;
        private String employeeName;
        private Long departmentId;
        private String departmentName;
        private String contractNo;
        /** PROBATION | FIXED_TERM | INDEFINITE | SEASONAL | SERVICE */
        private String contractType;
        /** Trạng thái lưu: DRAFT | ACTIVE | TERMINATED */
        private String status;
        /** Trạng thái hiển thị: DRAFT | ACTIVE | EXPIRED | TERMINATED */
        private String displayStatus;
        private LocalDate signDate;
        private LocalDate startDate;
        private LocalDate endDate;
        private BigDecimal baseSalary;
        private BigDecimal insuranceSalary;
        private String positionTitle;
        private String note;
        private LocalDate terminationDate;
        private String terminationReason;
        /** Lương / lương đóng BH / phụ cấp đang áp dụng hôm nay (theo phụ lục mới nhất). */
        private BigDecimal currentBaseSalary;
        private BigDecimal currentInsuranceSalary;
        private BigDecimal currentAllowanceTotal;
        /** Số ngày còn lại tới ngày kết thúc (âm = đã quá hạn); null = không thời hạn. */
        private Integer daysToEnd;
        /** Đã có hợp đồng nối tiếp (bắt đầu sau ngày kết thúc) — không còn "cần gia hạn". */
        private boolean renewed;
        private List<Allowance> allowances;
        private List<AppendixResponse> appendices;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class Upsert {
        @NotNull private Long employeeId;
        @NotBlank @Size(max = 50) private String contractNo;
        @NotBlank private String contractType;
        /** DRAFT | ACTIVE; không gửi = DRAFT khi tạo, giữ nguyên khi sửa. */
        private String status;
        private LocalDate signDate;
        @NotNull private LocalDate startDate;
        private LocalDate endDate;
        @NotNull private BigDecimal baseSalary;
        private BigDecimal insuranceSalary;
        @Size(max = 150) private String positionTitle;
        @Size(max = 1000) private String note;
        /** null = giữ nguyên khi sửa (không có khi tạo). */
        @Valid private List<Allowance> allowances;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class AppendixUpsert {
        @NotBlank @Size(max = 50) private String appendixNo;
        @NotNull private LocalDate effectiveFrom;
        private BigDecimal baseSalary;
        private BigDecimal insuranceSalary;
        @Size(max = 150) private String positionTitle;
        private boolean overridesAllowances;
        @Size(max = 1000) private String note;
        @Valid private List<Allowance> allowances;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class TerminateRequest {
        @NotNull private LocalDate terminationDate;
        @Size(max = 500) private String reason;
    }

    @Data @NoArgsConstructor
    public static class ImportRow {
        private String contractNo;
        private String employeeCode;
        private String employeeName;
        private String contractType;
        private String status;
        private String signDate;
        private String startDate;
        private String endDate;
        private String baseSalary;
        private String insuranceSalary;
        private String positionTitle;
        private String note;
    }

    @Data @NoArgsConstructor
    public static class AllowanceImportRow {
        private String contractNo;
        private String code;
        private String name;
        private String amount;
        private String insurable;
        private String taxable;
    }

    /** Dòng phụ cấp gốc khi xuất Excel. */
    public record AllowanceExportRow(String contractNo, Allowance allowance) {}

    @Data @Builder
    public static class ImportDiff {
        /** "CREATE" | "UPDATE" | "NO_CHANGE" */
        private String action;
        /** Số hợp đồng — khoá định danh dòng. */
        private String code;
        private String name;
        private List<DepartmentDTO.FieldChange> changes;
        private List<String> warnings;
    }
}
