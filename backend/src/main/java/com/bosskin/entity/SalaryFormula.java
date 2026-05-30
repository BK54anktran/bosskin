package com.bosskin.entity;

import com.fasterxml.jackson.databind.annotation.JsonDeserialize;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;

@Entity
@Table(name = "salary_formulas")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SalaryFormula extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "salary_grade_id", nullable = false)
    private SalaryGrade salaryGrade;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Column(name = "effective_date", nullable = false)
    private LocalDate effectiveDate;

    @Column(name = "expression_gross", nullable = false, columnDefinition = "TEXT")
    private String expressionGross;

    @Column(name = "expression_net", nullable = false, columnDefinition = "TEXT")
    private String expressionNet;

    // Private vars: {"VAR_NAME": "expression", ...}
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "custom_vars", columnDefinition = "JSON")
    @JsonDeserialize(as = LinkedHashMap.class)
    @Builder.Default
    private Map<String, String> customVars = new LinkedHashMap<>();

    // Deduction vars: {"VAR_NAME": {label, expression}, ...}
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "deduction_vars", columnDefinition = "JSON")
    @JsonDeserialize(as = LinkedHashMap.class)
    @Builder.Default
    private Map<String, DeductionVar> deductionVars = new LinkedHashMap<>();

    // Income vars: thu nhập thêm (cộng vào Gross, hiển thị riêng)
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "income_vars", columnDefinition = "JSON")
    @JsonDeserialize(as = LinkedHashMap.class)
    @Builder.Default
    private Map<String, DeductionVar> incomeVars = new LinkedHashMap<>();

    // Allowance vars: trợ cấp (cộng vào Gross, hiển thị riêng)
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "allowance_vars", columnDefinition = "JSON")
    @JsonDeserialize(as = LinkedHashMap.class)
    @Builder.Default
    private Map<String, DeductionVar> allowanceVars = new LinkedHashMap<>();

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class DeductionVar {
        private String label;
        private String expression;
        private int sortOrder;
    }
}
