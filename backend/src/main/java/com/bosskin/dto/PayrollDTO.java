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
        private BigDecimal otherDeductions;
        private Map<String, Payroll.DeductionEntry> customDeductions;
        private Map<String, Payroll.DeductionEntry> incomeEntries;
        private Map<String, Payroll.DeductionEntry> allowanceEntries;
        private BigDecimal netSalary;
        private Long salaryGradeId;
        private String salaryGradeCode;
        private String salaryGradeName;
        private String payType;
        private Integer standardWorkDays;
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
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
        private LocalDateTime paidAt;

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
                    .otherDeductions(p.getOtherDeductions())
                    .customDeductions(p.getCustomDeductions() != null ? p.getCustomDeductions() : Map.of())
                    .incomeEntries(p.getIncomeEntries() != null ? p.getIncomeEntries() : Map.of())
                    .allowanceEntries(p.getAllowanceEntries() != null ? p.getAllowanceEntries() : Map.of())
                    .netSalary(p.getNetSalary())
                    .salaryGradeId(emp.getSalaryGrade() != null ? emp.getSalaryGrade().getId() : null)
                    .salaryGradeCode(emp.getSalaryGrade() != null ? emp.getSalaryGrade().getCode() : null)
                    .salaryGradeName(emp.getSalaryGrade() != null ? emp.getSalaryGrade().getName() : null)
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
                    .paidAt(p.getPaidAt())
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
}
