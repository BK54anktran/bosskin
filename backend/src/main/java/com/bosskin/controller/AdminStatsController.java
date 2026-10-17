package com.bosskin.controller;

import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.PayrollRepository;
import com.bosskin.repository.UserRepository;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@RestController
@RequestMapping("/admin/stats")
@RequiredArgsConstructor
public class AdminStatsController {

    private final CompanyRepository  companyRepository;
    private final EmployeeRepository employeeRepository;
    private final UserRepository     userRepository;
    private final PayrollRepository  payrollRepository;

    @GetMapping
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ResponseEntity<SystemStats> getStats(
            @org.springframework.web.bind.annotation.RequestParam(required = false) Integer year,
            @org.springframework.web.bind.annotation.RequestParam(required = false) Integer month) {
        long totalCompanies  = companyRepository.count();
        long activeCompanies = companyRepository.findAll().stream().filter(c -> c.isActive()).count();
        long totalEmployees  = employeeRepository.count();
        long totalUsers      = userRepository.count();

        LocalDate now = com.bosskin.core.CompanyZone.today();
        final int finalYear  = (year  != null) ? year  : now.getYear();
        final int finalMonth = (month != null) ? month : now.getMonthValue();

        // payroll stats: tổng lương tháng này theo từng công ty
        List<CompanyPayrollStat> payrollStats = new ArrayList<>();
        companyRepository.findAll().forEach(c -> {
            BigDecimal total = payrollRepository.sumNetSalaryByCompanyAndMonth(c.getId(), finalYear, finalMonth);
            long count = payrollRepository.countByCompanyAndMonth(c.getId(), finalYear, finalMonth);
            if (count > 0) {
                payrollStats.add(CompanyPayrollStat.builder()
                    .companyId(c.getId())
                    .companyName(c.getName())
                    .employeeCount(employeeRepository.countByCompanyId(c.getId()))
                    .payrollCount(count)
                    .totalNetSalary(total != null ? total : BigDecimal.ZERO)
                    .build());
            }
        });

        // growth: số công ty tạo theo tháng trong 12 tháng gần nhất
        List<MonthlyGrowth> growth = new ArrayList<>();
        for (int i = 11; i >= 0; i--) {
            LocalDate m = now.minusMonths(i).withDayOfMonth(1);
            final int y = m.getYear(), mo = m.getMonthValue();
            long cnt = companyRepository.findAll().stream()
                .filter(c -> c.getCreatedAt() != null
                    && c.getCreatedAt().getYear() == y
                    && c.getCreatedAt().getMonthValue() == mo)
                .count();
            growth.add(MonthlyGrowth.builder().year(y).month(mo).count(cnt).build());
        }

        return ResponseEntity.ok(SystemStats.builder()
            .totalCompanies(totalCompanies)
            .activeCompanies(activeCompanies)
            .inactiveCompanies(totalCompanies - activeCompanies)
            .totalEmployees(totalEmployees)
            .totalUsers(totalUsers)
            .currentYear(finalYear)
            .currentMonth(finalMonth)
            .companyPayrollStats(payrollStats)
            .companyGrowth(growth)
            .build());
    }

    @Getter @Builder
    public static class SystemStats {
        private long totalCompanies;
        private long activeCompanies;
        private long inactiveCompanies;
        private long totalEmployees;
        private long totalUsers;
        private int  currentYear;
        private int  currentMonth;
        private List<CompanyPayrollStat> companyPayrollStats;
        private List<MonthlyGrowth>      companyGrowth;
    }

    @Getter @Builder
    public static class CompanyPayrollStat {
        private Long       companyId;
        private String     companyName;
        private long       employeeCount;
        private long       payrollCount;
        private BigDecimal totalNetSalary;
    }

    @Getter @Builder
    public static class MonthlyGrowth {
        private int  year;
        private int  month;
        private long count;
    }
}
