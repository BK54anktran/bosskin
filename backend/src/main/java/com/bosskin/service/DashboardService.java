package com.bosskin.service;

import com.bosskin.dto.DashboardDTO;
import com.bosskin.entity.Attendance;
import com.bosskin.entity.AttendanceRequest;
import com.bosskin.entity.Company;
import com.bosskin.entity.Employee;
import com.bosskin.entity.SalaryGrade;
import com.bosskin.entity.Payroll;
import com.bosskin.entity.User;
import com.bosskin.repository.AttendanceRepository;
import com.bosskin.repository.AttendanceRequestRepository;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.LeaveRequestRepository;
import com.bosskin.repository.PayrollRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.List;
import java.util.Comparator;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.data.domain.PageRequest;

@Service
@RequiredArgsConstructor
public class DashboardService {

    private final EmployeeRepository employeeRepository;
    private final AttendanceRepository attendanceRepository;
    private final AttendanceRequestRepository attendanceRequestRepository;
    private final LeaveRequestRepository leaveRequestRepository;
    private final CompanyRepository companyRepository;
    private final PayrollRepository payrollRepository;
    private final AttendanceCalculationService calcSvc;

    @Transactional(readOnly = true)
    public DashboardDTO.Response getDashboard(User user, Long departmentId, LocalDate date) {
        Long companyId = user.getCompanyId();
        LocalDate today = date != null ? date : LocalDate.now();

        long totalEmployees = departmentId != null
            ? employeeRepository.countByCompanyIdAndDepartmentId(companyId, departmentId)
            : employeeRepository.countByCompanyId(companyId);

        List<Attendance> todayAttendances = departmentId != null
            ? attendanceRepository.findByCompanyAndDateAndDept(companyId, today, departmentId)
            : attendanceRepository.findByCompanyAndDate(companyId, today);

        // Load applied requests cho ngÃ y nÃ y â€” dÃ¹ng Ä‘á»ƒ tÃ­nh effective check-in/out
        List<AttendanceRequest> allRequests =
            attendanceRequestRepository.findByCompanyAndRequestDate(companyId, today);
        Map<Long, List<AttendanceRequest>> requestsByEmployee = allRequests.stream()
            .filter(r -> r.getStatus() == AttendanceRequest.Status.APPROVED && r.isApplied())
            .collect(Collectors.groupingBy(r -> r.getEmployee().getId()));

        long onLeave = departmentId != null
            ? leaveRequestRepository.findApprovedByCompanyAndDateAndDept(companyId, today, departmentId).size()
            : leaveRequestRepository.findApprovedByCompanyAndDate(companyId, today).size();

        // CÃ³ máº·t thá»±c sá»±: pháº£i cÃ³ checkIn, hoáº·c override, hoáº·c Ä‘Ã£ approve vá»›i snap hours > 0
        long present = todayAttendances.stream()
            .filter(a -> isActuallyPresent(a))
            .count();

        // LATE: dÃ¹ng workFlags náº¿u Ä‘Ã£ approved (nguá»“n chÃ­nh xÃ¡c nháº¥t),
        // ngÆ°á»£c láº¡i dÃ¹ng status == LATE Ä‘Æ°á»£c set lÃºc check-in theo shift + tolerance
        long late = todayAttendances.stream()
            .filter(a -> isActuallyPresent(a) && isLate(a))
            .count();

        long absent = Math.max(0, totalEmployees - present - onLeave);

        List<DashboardDTO.AttendanceRow> attendanceRows = todayAttendances.stream()
            .limit(20)
            .map(a -> {
                Employee emp = a.getEmployee();
                List<AttendanceRequest> empRequests = requestsByEmployee.getOrDefault(emp.getId(), List.of());

                // Effective check-in: chá»n cÃ¡i sá»›m hÆ¡n giá»¯a actual vÃ  applied request
                LocalTime actualIn  = a.getCheckIn()  != null ? a.getCheckIn().toLocalTime()  : null;
                LocalTime actualOut = a.getCheckOut() != null ? a.getCheckOut().toLocalTime() : null;

                LocalTime reqIn = empRequests.stream()
                    .filter(r -> r.getRequestType() == AttendanceRequest.Type.CHECK_IN
                              && r.getRequestedCheckIn() != null)
                    .map(AttendanceRequest::getRequestedCheckIn)
                    .findFirst().orElse(null);
                LocalTime reqOut = empRequests.stream()
                    .filter(r -> r.getRequestType() == AttendanceRequest.Type.CHECK_OUT
                              && r.getRequestedCheckOut() != null)
                    .map(AttendanceRequest::getRequestedCheckOut)
                    .findFirst().orElse(null);

                LocalTime effectiveIn  = earlierOf(actualIn,  reqIn);
                LocalTime effectiveOut = laterOf(actualOut, reqOut);

                // Náº¿u override, Æ°u tiÃªn override
                if (a.getOverrideCheckIn()  != null) effectiveIn  = a.getOverrideCheckIn();
                if (a.getOverrideCheckOut() != null) effectiveOut = a.getOverrideCheckOut();

                LocalDateTime displayIn  = effectiveIn  != null ? today.atTime(effectiveIn)  : null;
                LocalDateTime displayOut = effectiveOut != null ? today.atTime(effectiveOut) : null;

                boolean actuallyPresent = isActuallyPresent(a);
                return DashboardDTO.AttendanceRow.builder()
                    .employeeId(emp.getId())
                    .employeeCode(emp.getEmployeeCode())
                    .employeeName(emp.getFullName())
                    .departmentName(emp.getDepartment() != null ? emp.getDepartment().getName() : null)
                    .checkIn(actuallyPresent ? displayIn : null)
                    .checkOut(actuallyPresent ? displayOut : null)
                    .status(actuallyPresent ? a.getStatus().name() : Attendance.Status.ABSENT.name())
                    .late(actuallyPresent && isLate(a))
                    .build();
            })
            .collect(Collectors.toList());

        DashboardDTO.TodayStats stats = DashboardDTO.TodayStats.builder()
            .totalEmployees(totalEmployees)
            .present(present)
            .onLeave(onLeave)
            .absent(absent)
            .late(late)
            .build();

        YearMonth ym = YearMonth.now();
        DashboardDTO.RecentPayroll recentPayroll = buildRecentPayroll(companyId, ym);
        if (recentPayroll.getEmployeeCount() == 0) {
            recentPayroll = buildRecentPayroll(companyId, ym.minusMonths(1));
        }

        return DashboardDTO.Response.builder()
            .date(today)
            .todayStats(stats)
            .todayAttendance(attendanceRows)
            .recentPayroll(recentPayroll)
            .build();
    }

    private boolean isActuallyPresent(Attendance a) { return calcSvc.isActuallyPresent(a); }
    private boolean isLate(Attendance a) { return calcSvc.isLate(a); }

    private LocalTime earlierOf(LocalTime a, LocalTime b) {
        if (a == null) return b;
        if (b == null) return a;
        return a.isBefore(b) ? a : b;
    }

    private LocalTime laterOf(LocalTime a, LocalTime b) {
        if (a == null) return b;
        if (b == null) return a;
        return a.isAfter(b) ? a : b;
    }

    @Transactional(readOnly = true)
    public DashboardDTO.RangeResponse getRangeDashboard(User user, Long departmentId, LocalDate from, LocalDate to) {
        Long companyId = user.getCompanyId();

        long totalEmployees = departmentId != null
            ? employeeRepository.countByCompanyIdAndDepartmentId(companyId, departmentId)
            : employeeRepository.countByCompanyId(companyId);

        List<Attendance> attendances = departmentId != null
            ? attendanceRepository.findByCompanyAndDateRangeAndDept(companyId, from, to, departmentId)
            : attendanceRepository.findByCompanyAndDateRange(companyId, from, to);

        // Group by employee
        Map<Long, List<Attendance>> byEmployee = attendances.stream()
            .collect(Collectors.groupingBy(a -> a.getEmployee().getId()));

        long totalWorkDays = 0, totalLateDays = 0, totalAbsentDays = 0, totalLeaveDays = 0;

        List<DashboardDTO.RangeEmployeeRow> rows = new java.util.ArrayList<>();
        for (Map.Entry<Long, List<Attendance>> entry : byEmployee.entrySet()) {
            List<Attendance> empAtts = entry.getValue();
            Employee emp = empAtts.get(0).getEmployee();

            long present = empAtts.stream().filter(a -> isActuallyPresent(a) && !isLate(a)).count();
            long late    = empAtts.stream().filter(a -> isActuallyPresent(a) && isLate(a)).count();
            // absent/leave: approved â†’ dÃ¹ng status; chÆ°a approved â†’ khÃ´ng cÃ³ checkIn vÃ  khÃ´ng cÃ³ override
            long absent  = empAtts.stream().filter(a -> a.isApproved()
                ? Attendance.Status.ABSENT == a.getStatus()
                : (a.getCheckIn() == null && a.getOverrideCheckIn() == null)).count();
            long leave   = empAtts.stream().filter(a -> Attendance.Status.LEAVE == a.getStatus()).count();

            totalWorkDays  += present + late;
            totalLateDays  += late;
            totalAbsentDays += absent;
            totalLeaveDays  += leave;

            rows.add(DashboardDTO.RangeEmployeeRow.builder()
                .employeeId(emp.getId())
                .employeeCode(emp.getEmployeeCode())
                .employeeName(emp.getFullName())
                .departmentName(emp.getDepartment() != null ? emp.getDepartment().getName() : null)
                .presentDays(present + late)
                .lateDays(late)
                .absentDays(absent)
                .leaveDays(leave)
                .build());
        }

        rows.sort(java.util.Comparator.comparing(DashboardDTO.RangeEmployeeRow::getEmployeeName));

        // Daily trend: group by date, count totals
        Map<LocalDate, List<Attendance>> byDate = attendances.stream()
            .collect(Collectors.groupingBy(Attendance::getDate));
        List<DashboardDTO.RangeDailyPoint> dailyTrend = byDate.entrySet().stream()
            .sorted(Map.Entry.comparingByKey())
            .map(e -> {
                List<Attendance> dayAtts = e.getValue();
                long p = dayAtts.stream().filter(a -> isActuallyPresent(a) && !isLate(a)).count();
                long l = dayAtts.stream().filter(a -> isActuallyPresent(a) && isLate(a)).count();
                long ab = dayAtts.stream().filter(a -> a.isApproved()
                    ? Attendance.Status.ABSENT == a.getStatus()
                    : (a.getCheckIn() == null && a.getOverrideCheckIn() == null)).count();
                long lv = dayAtts.stream().filter(a -> Attendance.Status.LEAVE == a.getStatus()).count();
                return DashboardDTO.RangeDailyPoint.builder()
                    .date(e.getKey())
                    .present(p)
                    .late(l)
                    .absent(ab)
                    .onLeave(lv)
                    .build();
            })
            .collect(Collectors.toList());

        return DashboardDTO.RangeResponse.builder()
            .from(from)
            .to(to)
            .stats(DashboardDTO.RangeStats.builder()
                .totalEmployees(totalEmployees)
                .totalWorkDays(totalWorkDays)
                .totalLateDays(totalLateDays)
                .totalAbsentDays(totalAbsentDays)
                .totalLeaveDays(totalLeaveDays)
                .build())
            .rows(rows)
            .dailyTrend(dailyTrend)
            .build();
    }

    @Transactional(readOnly = true)
    public DashboardDTO.AnalyticsResponse getAnalytics(User user, Long departmentId, int year) {
        Long companyId = user.getCompanyId();
        Company company = companyRepository.findById(companyId)
            .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.NOT_FOUND, "error.company.not_found"));
        LocalDate yearStart = LocalDate.of(year, 1, 1);
        LocalDate yearEnd   = LocalDate.of(year, 12, 31);

        // Salary trend 12 thÃ¡ng
        List<DashboardDTO.MonthlySalaryStat> salaryTrend = new ArrayList<>();
        for (Object[] row : payrollRepository.findMonthlySalaryTrend(companyId, year)) {
            salaryTrend.add(DashboardDTO.MonthlySalaryStat.builder()
                .month(((Number) row[0]).intValue())
                .totalNetSalary(row[1] != null ? (BigDecimal) row[1] : BigDecimal.ZERO)
                .employeeCount(((Number) row[2]).longValue())
                .build());
        }

        // Attendance trend 90 ngày g?n nh?t
        LocalDate trendFrom = LocalDate.now().minusDays(89);
        LocalDate trendTo   = LocalDate.now();

        Map<LocalDate, List<Attendance>> attendanceByDate = (departmentId != null
            ? attendanceRepository.findByCompanyAndDateRangeAndDept(companyId, trendFrom, trendTo, departmentId)
            : attendanceRepository.findByCompanyAndDateRange(companyId, trendFrom, trendTo))
            .stream()
            .collect(Collectors.groupingBy(Attendance::getDate));

        List<DashboardDTO.DailyAttendanceStat> attendanceTrend = new ArrayList<>();
        List<LocalDate> dates = attendanceByDate.keySet().stream()
            .sorted(Comparator.naturalOrder())
            .toList();
        for (LocalDate date : dates) {
            List<Attendance> dayAttendances = attendanceByDate.getOrDefault(date, List.of());
            List<DashboardDTO.DailyAttendanceGradeBreakdown> gradeBreakdown = buildGradeBreakdown(dayAttendances, company);
            BigDecimal estimated = gradeBreakdown.stream()
                .map(DashboardDTO.DailyAttendanceGradeBreakdown::getEstimatedCost)
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .setScale(0, RoundingMode.HALF_UP);
            long present = dayAttendances.stream().filter(a -> isActuallyPresent(a) && !isLate(a)).count();
            long late = dayAttendances.stream().filter(a -> isActuallyPresent(a) && isLate(a)).count();
            long absent = dayAttendances.stream().filter(a -> a.getStatus() == Attendance.Status.ABSENT).count();
            double totalHours = gradeBreakdown.stream()
                .mapToDouble(DashboardDTO.DailyAttendanceGradeBreakdown::getTotalHours)
                .sum();
            attendanceTrend.add(DashboardDTO.DailyAttendanceStat.builder()
                .date(date)
                .present(present)
                .late(late)
                .absent(absent)
                .totalHours(totalHours)
                .estimatedCost(estimated)
                .gradeBreakdown(gradeBreakdown)
                .build());
        }

        // Top 10 nhÃ¢n viÃªn Ä‘i muá»™n trong nÄƒm
        List<DashboardDTO.TopLateEmployee> topLate = new ArrayList<>();
        for (Object[] row : attendanceRepository.findTopLateEmployees(companyId, yearStart, yearEnd, departmentId, PageRequest.of(0, 10))) {
            topLate.add(DashboardDTO.TopLateEmployee.builder()
                .employeeId(((Number) row[0]).longValue())
                .employeeCode((String) row[1])
                .employeeName((String) row[2])
                .departmentName((String) row[3])
                .lateDays(((Number) row[4]).longValue())
                .build());
        }

        // Overall stats cho nÄƒm
        List<Attendance> yearAtts = departmentId != null
            ? attendanceRepository.findByCompanyAndDateRangeAndDept(companyId, yearStart, yearEnd, departmentId)
            : attendanceRepository.findByCompanyAndDateRange(companyId, yearStart, yearEnd);

        long totalEmployees = departmentId != null
            ? employeeRepository.countByCompanyIdAndDepartmentId(companyId, departmentId)
            : employeeRepository.countByCompanyId(companyId);

        Map<Long, List<Attendance>> byEmp = yearAtts.stream()
            .collect(Collectors.groupingBy(a -> a.getEmployee().getId()));

        long totalWorkDays = 0, totalLate = 0, totalAbsent = 0, totalLeave = 0;
        for (List<Attendance> empAtts : byEmp.values()) {
            totalWorkDays += empAtts.stream().filter(a -> isActuallyPresent(a)).count();
            totalLate     += empAtts.stream().filter(a -> isActuallyPresent(a) && isLate(a)).count();
            totalAbsent   += empAtts.stream().filter(a -> Attendance.Status.ABSENT == a.getStatus()).count();
            totalLeave    += empAtts.stream().filter(a -> Attendance.Status.LEAVE  == a.getStatus()).count();
        }

        return DashboardDTO.AnalyticsResponse.builder()
            .year(year)
            .salaryTrend(salaryTrend)
            .attendanceTrend(attendanceTrend)
            .topLate(topLate)
            .overallStats(DashboardDTO.RangeStats.builder()
                .totalEmployees(totalEmployees)
                .totalWorkDays(totalWorkDays)
                .totalLateDays(totalLate)
                .totalAbsentDays(totalAbsent)
                .totalLeaveDays(totalLeave)
                .build())
            .build();
    }


    private List<DashboardDTO.DailyAttendanceGradeBreakdown> buildGradeBreakdown(List<Attendance> attendances, Company company) {
        if (attendances == null || attendances.isEmpty()) {
            return List.of();
        }

        BigDecimal hoursPerDay = company.getLeaveHoursPerDay() != null
            && company.getLeaveHoursPerDay().compareTo(BigDecimal.ZERO) > 0
            ? company.getLeaveHoursPerDay()
            : BigDecimal.valueOf(8);

        Map<Long, GradeAcc> byGrade = new java.util.LinkedHashMap<>();
        for (Attendance attendance : attendances) {
            if (attendance == null || attendance.getEmployee() == null) continue;
            SalaryGrade grade = attendance.getEmployee().getSalaryGrade();
            if (grade == null || grade.getBaseRate() == null || grade.getBaseRate().compareTo(BigDecimal.ZERO) <= 0) continue;

            double actualHours = resolveActualHours(attendance);
            if (actualHours <= 0d) continue;

            BigDecimal hourlyRate = grade.getPayType() == SalaryGrade.PayType.HOURLY
                ? grade.getBaseRate()
                : grade.getBaseRate().divide(hoursPerDay, 8, RoundingMode.HALF_UP);
            BigDecimal estimated = hourlyRate.multiply(BigDecimal.valueOf(actualHours));

            GradeAcc acc = byGrade.computeIfAbsent(grade.getId(), k -> new GradeAcc(grade));
            acc.totalHours = acc.totalHours.add(BigDecimal.valueOf(actualHours));
            acc.estimatedCost = acc.estimatedCost.add(estimated);
            acc.employeeIds.add(attendance.getEmployee().getId());
        }

        return byGrade.values().stream()
            .map(acc -> DashboardDTO.DailyAttendanceGradeBreakdown.builder()
                .salaryGradeId(acc.grade.getId())
                .salaryGradeCode(acc.grade.getCode())
                .salaryGradeName(acc.grade.getName())
                .payType(acc.grade.getPayType() != null ? acc.grade.getPayType().name() : null)
                .totalHours(acc.totalHours.setScale(2, RoundingMode.HALF_UP).doubleValue())
                .estimatedCost(acc.estimatedCost.setScale(0, RoundingMode.HALF_UP))
                .employeeCount(acc.employeeIds.size())
                .build())
            .toList();
    }

    private BigDecimal estimateDailyCost(List<Attendance> attendances, Company company) {
        if (attendances == null || attendances.isEmpty()) {
            return BigDecimal.ZERO;
        }
        return buildGradeBreakdown(attendances, company).stream()
            .map(DashboardDTO.DailyAttendanceGradeBreakdown::getEstimatedCost)
            .reduce(BigDecimal.ZERO, BigDecimal::add)
            .setScale(0, RoundingMode.HALF_UP);
    }

    private static class GradeAcc {
        final SalaryGrade grade;
        BigDecimal totalHours = BigDecimal.ZERO;
        BigDecimal estimatedCost = BigDecimal.ZERO;
        final java.util.Set<Long> employeeIds = new java.util.HashSet<>();

        GradeAcc(SalaryGrade grade) {
            this.grade = grade;
        }
    }

    private double resolveActualHours(Attendance attendance) {
        if (attendance.getSnapActualHours() != null && attendance.getSnapActualHours() > 0) {
            return attendance.getSnapActualHours();
        }

        double total = 0d;
        if (attendance.getSnapDayHours() != null) total += attendance.getSnapDayHours();
        if (attendance.getSnapNightHours() != null) total += attendance.getSnapNightHours();
        if (attendance.getSnapDayOt() != null) total += attendance.getSnapDayOt();
        if (attendance.getSnapNightOt() != null) total += attendance.getSnapNightOt();
        return total;
    }

    private DashboardDTO.RecentPayroll buildRecentPayroll(Long companyId, YearMonth ym) {
        long count = payrollRepository.countByCompanyAndMonth(companyId, ym.getYear(), ym.getMonthValue());
        BigDecimal total = payrollRepository.sumNetSalaryByCompanyAndMonth(companyId, ym.getYear(), ym.getMonthValue());
        List<Object[]> statusRows = payrollRepository.findStatusSummaryByCompanyAndMonth(companyId, ym.getYear(), ym.getMonthValue());

        String dominantStatus = "DRAFT";
        if (!statusRows.isEmpty()) {
            dominantStatus = ((Payroll.Status) statusRows.get(0)[0]).name();
        }

        return DashboardDTO.RecentPayroll.builder()
            .year(ym.getYear())
            .month(ym.getMonthValue())
            .totalNetSalary(total != null ? total : BigDecimal.ZERO)
            .employeeCount(count)
            .status(dominantStatus)
            .build();
    }
}
