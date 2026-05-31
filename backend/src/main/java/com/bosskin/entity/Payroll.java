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

    @Column(name = "standard_work_days")
    private Integer standardWorkDays;

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

    @Column(name = "approved_at")
    private LocalDateTime approvedAt;

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
}
