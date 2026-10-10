package com.bosskin.entity;

import com.fasterxml.jackson.databind.annotation.JsonDeserialize;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

@Entity
@Table(name = "payrolls",
    uniqueConstraints = @UniqueConstraint(columnNames = {"employee_id", "year", "month"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Payroll extends BaseEntity {

    public enum Status { DRAFT, APPROVED, PAID }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @Column(name = "year", nullable = false)
    private Integer year;

    @Column(name = "month", nullable = false)
    private Integer month;

    @Column(name = "base_salary", nullable = false, precision = 15, scale = 2)
    private BigDecimal baseSalary;

    @Column(name = "allowance", precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal allowance = BigDecimal.ZERO;

    @Column(name = "bonus", precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal bonus = BigDecimal.ZERO;

    @Column(name = "overtime_pay", precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal overtimePay = BigDecimal.ZERO;

    @Column(name = "gross_salary", nullable = false, precision = 15, scale = 2)
    private BigDecimal grossSalary;

    @Column(name = "social_insurance", precision = 15, scale = 2)
    private BigDecimal socialInsurance;

    @Column(name = "health_insurance", precision = 15, scale = 2)
    private BigDecimal healthInsurance;

    @Column(name = "unemployment_insurance", precision = 15, scale = 2)
    private BigDecimal unemploymentInsurance;

    @Column(name = "personal_income_tax", precision = 15, scale = 2)
    private BigDecimal personalIncomeTax;

    @Column(name = "other_deductions", precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal otherDeductions = BigDecimal.ZERO;

    @Column(name = "net_salary", nullable = false, precision = 15, scale = 2)
    private BigDecimal netSalary;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    @Builder.Default
    private Status status = Status.DRAFT;

    @Column(name = "pay_type", length = 10)
    private String payType; // DAILY | HOURLY

    @Column(name = "salary_grade_id")
    private Long salaryGradeId;

    /** Bước K — phòng ban hiệu lực ở ngày cuối kỳ (snapshot). */
    @Column(name = "department_id")
    private Long departmentId;

    @Column(name = "department_name")
    private String departmentName;

    @Column(name = "salary_grade_code", length = 50)
    private String salaryGradeCode;

    @Column(name = "salary_grade_name", length = 255)
    private String salaryGradeName;

    /** Công chuẩn kỳ (V14: có thể lẻ nửa ngày khi tính theo lịch tuần). */
    @Column(name = "standard_work_days", precision = 5, scale = 2)
    private java.math.BigDecimal standardWorkDays;

    @Column(name = "period_from")
    private LocalDate periodFrom;

    @Column(name = "period_to")
    private LocalDate periodTo;

    @Column(name = "present_days")
    private Integer presentDays;

    @Column(name = "total_overtime_hours", precision = 8, scale = 2)
    private BigDecimal totalOvertimeHours;

    @Column(name = "day_hours", precision = 8, scale = 2)
    private BigDecimal dayHours;

    @Column(name = "night_hours", precision = 8, scale = 2)
    private BigDecimal nightHours;

    @Column(name = "day_ot", precision = 8, scale = 2)
    private BigDecimal dayOt;

    @Column(name = "night_ot", precision = 8, scale = 2)
    private BigDecimal nightOt;

    @Column(name = "note", columnDefinition = "TEXT")
    private String note;

    @Column(name = "paid_at")
    private LocalDateTime paidAt;

    /** Giảm trừ gia cảnh đã dùng khi tính thuế (bản thân + người phụ thuộc), V13. */
    @Column(name = "family_deduction", precision = 15, scale = 2)
    private BigDecimal familyDeduction;

    /** Lương đóng BHXH/BHYT sau khi áp trần, V13. */
    @Column(name = "insurance_base", precision = 15, scale = 2)
    private BigDecimal insuranceBase;

    @Column(name = "approved_at")
    private LocalDateTime approvedAt;

    /** Người duyệt bảng lương (L18). */
    @Column(name = "approved_by_id")
    private Long approvedById;

    /** Người xác nhận đã trả lương (L18). */
    @Column(name = "paid_by_id")
    private Long paidById;

    // Inline formula snapshot — chỉ áp dụng cho payroll này, không lưu vào salary_formulas
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "custom_formula", columnDefinition = "JSON")
    private CustomFormula customFormula;

    // Snapshot các khoản khấu trừ tùy chỉnh khi generate: {"VAR_NAME": {label, amount}}
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "custom_deductions", columnDefinition = "JSON")
    @JsonDeserialize(as = LinkedHashMap.class)
    @Builder.Default
    private Map<String, DeductionEntry> customDeductions = new LinkedHashMap<>();

    // Snapshot thu nhập thêm
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "income_entries", columnDefinition = "JSON")
    @JsonDeserialize(as = LinkedHashMap.class)
    @Builder.Default
    private Map<String, DeductionEntry> incomeEntries = new LinkedHashMap<>();

    // Snapshot trợ cấp
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "allowance_entries", columnDefinition = "JSON")
    @JsonDeserialize(as = LinkedHashMap.class)
    @Builder.Default
    private Map<String, DeductionEntry> allowanceEntries = new LinkedHashMap<>();

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class DeductionEntry {
        private String label;
        private BigDecimal amount;
        private int sortOrder;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class CustomFormula {
        private String name;
        private String expressionGross;
        private String expressionNet;
        private Map<String, String> customVars;
        private Map<String, SalaryFormula.DeductionVar> deductionVars;
        private Map<String, SalaryFormula.DeductionVar> incomeVars;
        private Map<String, SalaryFormula.DeductionVar> allowanceVars;
    }

    /**
     * Tổng khấu trừ thống nhất cho phiếu lương, màn hình, Excel và báo cáo: GROSS − NET.
     * Bao gồm mọi khoản công thức NET trừ (bảo hiểm, thuế, khoản khấu trừ tuỳ chỉnh) và khấu trừ khác nhập tay,
     * nên luôn khớp với NET thực nhận, không cộng trùng khi công ty tự định nghĩa biến bảo hiểm.
     */
    public BigDecimal totalDeduction() {
        BigDecimal gross = grossSalary != null ? grossSalary : BigDecimal.ZERO;
        BigDecimal net = netSalary != null ? netSalary : BigDecimal.ZERO;
        return gross.subtract(net);
    }
}
