package com.bosskin.dto;

import com.bosskin.entity.Payroll;
import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Map;

public class PayrollDTO {

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class Response {
        private Long id;
        private Long employeeId;
        private String employeeName;
        private String departmentName;
        private String positionName;
        private Integer year;
        private Integer month;
        private BigDecimal baseSalary;
        private BigDecimal allowance;
        private BigDecimal bonus;
        private BigDecimal overtimePay;
        private BigDecimal grossSalary;
        private BigDecimal socialInsurance;
        private BigDecimal healthInsurance;
        private BigDecimal unemploymentInsurance;
        private BigDecimal personalIncomeTax;
        /** Giảm trừ gia cảnh đã dùng (bản thân + người phụ thuộc), V13. */
        private BigDecimal familyDeduction;
        /** Lương đóng BHXH/BHYT sau trần, V13. */
        private BigDecimal insuranceBase;
        /** Tổng khấu trừ thống nhất = GROSS − NET (Payroll.totalDeduction). */
        private BigDecimal totalDeduction;
        private BigDecimal otherDeductions;
        private Map<String, Payroll.DeductionEntry> customDeductions;
        private Map<String, Payroll.DeductionEntry> incomeEntries;
        private Map<String, Payroll.DeductionEntry> allowanceEntries;
        private BigDecimal netSalary;
        private Long salaryGradeId;
        private String salaryGradeCode;
        private String salaryGradeName;
        private String payType;
        private java.math.BigDecimal standardWorkDays;
        @JsonFormat(pattern = "yyyy-MM-dd")
        private LocalDate periodFrom;
        @JsonFormat(pattern = "yyyy-MM-dd")
        private LocalDate periodTo;
        private Integer presentDays;
        private BigDecimal totalOvertimeHours;
        private BigDecimal dayHours;
        private BigDecimal nightHours;
        private BigDecimal dayOt;
        private BigDecimal nightOt;
        private Payroll.Status status;
        private String note;
        private Payroll.CustomFormula customFormula;
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
        private LocalDateTime approvedAt;
        private Long approvedById;
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
        private LocalDateTime paidAt;
        private Long paidById;

        public static Response from(Payroll p) {
            var emp = p.getEmployee();
            return Response.builder()
                    .id(p.getId())
                    .employeeId(emp.getId())
                    .employeeName(emp.getFullName())
                    .departmentName(emp.getDepartment() != null ? emp.getDepartment().getName() : null)
                    .positionName(emp.getPosition() != null ? emp.getPosition().getName() : null)
                    .year(p.getYear())
                    .month(p.getMonth())
                    .baseSalary(p.getBaseSalary())
                    .allowance(p.getAllowance())
                    .bonus(p.getBonus())
                    .overtimePay(p.getOvertimePay())
                    .grossSalary(p.getGrossSalary())
                    .socialInsurance(p.getSocialInsurance())
                    .healthInsurance(p.getHealthInsurance())
                    .unemploymentInsurance(p.getUnemploymentInsurance())
                    .personalIncomeTax(p.getPersonalIncomeTax())
                    .familyDeduction(p.getFamilyDeduction())
                    .insuranceBase(p.getInsuranceBase())
                    .totalDeduction(p.totalDeduction())
                    .otherDeductions(p.getOtherDeductions())
                    .customDeductions(p.getCustomDeductions() != null ? p.getCustomDeductions() : Map.of())
                    .incomeEntries(p.getIncomeEntries() != null ? p.getIncomeEntries() : Map.of())
                    .allowanceEntries(p.getAllowanceEntries() != null ? p.getAllowanceEntries() : Map.of())
                    .netSalary(p.getNetSalary())
                    // Ưu tiên snapshot trong payroll, fallback sang grade hiện tại của employee
                    .salaryGradeId(p.getSalaryGradeId() != null ? p.getSalaryGradeId()
                        : (emp.getSalaryGrade() != null ? emp.getSalaryGrade().getId() : null))
                    .salaryGradeCode(p.getSalaryGradeCode() != null ? p.getSalaryGradeCode()
                        : (emp.getSalaryGrade() != null ? emp.getSalaryGrade().getCode() : null))
                    .salaryGradeName(p.getSalaryGradeName() != null ? p.getSalaryGradeName()
                        : (emp.getSalaryGrade() != null ? emp.getSalaryGrade().getName() : null))
                    .payType(p.getPayType())
                    .standardWorkDays(p.getStandardWorkDays())
                    .periodFrom(p.getPeriodFrom())
                    .periodTo(p.getPeriodTo())
                    .presentDays(p.getPresentDays())
                    .totalOvertimeHours(p.getTotalOvertimeHours())
                    .dayHours(p.getDayHours())
                    .nightHours(p.getNightHours())
                    .dayOt(p.getDayOt())
                    .nightOt(p.getNightOt())
                    .status(p.getStatus())
                    .note(p.getNote())
                    .customFormula(p.getCustomFormula())
                    .approvedAt(p.getApprovedAt())
                    .approvedById(p.getApprovedById())
                    .paidAt(p.getPaidAt())
                    .paidById(p.getPaidById())
                    .build();
        }
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class PatchRequest {
        private BigDecimal allowance;
        private BigDecimal bonus;
        private BigDecimal otherDeductions;
        private String note;
        private Payroll.CustomFormula customFormula;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class ImportRow {
        private String year;
        private String month;
        private String employeeCode;
        private String employeeName;           // read-only
        private String departmentName;         // read-only
        private String positionName;           // read-only
        private String salaryGradeCode;        // read-only
        private String payType;                // read-only
        private String periodFrom;             // dd/MM/yyyy read-only
        private String periodTo;               // dd/MM/yyyy read-only
        private String standardWorkDays;       // read-only
        private String presentDays;            // read-only
        private String baseSalary;             // read-only
        private String allowance;
        private String bonus;
        private String overtimePay;            // read-only
        private String grossSalary;            // read-only
        private String socialInsurance;        // read-only
        private String healthInsurance;        // read-only
        private String unemploymentInsurance;  // read-only
        private String personalIncomeTax;      // read-only
        private String otherDeductions;
        private String netSalary;              // read-only
        private String status;                 // read-only
        private String note;
        private String dayHours;               // read-only
        private String nightHours;             // read-only
        private String dayOt;                  // read-only
        private String nightOt;                // read-only
        private String totalAllowance;         // read-only: allowanceEntries + allowance + bonus
        private String totalIncome;            // read-only: incomeEntries + overtimePay
        private String totalDeduction;         // read-only: GROSS − NET (Payroll.totalDeduction)
    }
}
