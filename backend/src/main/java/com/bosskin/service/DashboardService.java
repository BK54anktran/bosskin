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
import com.bosskin.repository.ShiftAssignmentRepository;
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
    private final ShiftAssignmentRepository shiftAssignmentRepository;
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

        // Load approved requests cho ngay nay -- dung de tinh effective check-in/out
        List<AttendanceRequest> allRequests =
            attendanceRequestRepository.findByCompanyAndRequestDate(companyId, today);
        Map<Long, List<AttendanceRequest>> requestsByEmployee = allRequests.stream()
            .filter(r -> r.getStatus() == AttendanceRequest.Status.APPROVED && r.isApplied())
            .collect(Collectors.groupingBy(r -> r.getEmployee().getId()));

        long onLeave = departmentId != null
            ? leaveRequestRepository.findApprovedByCompanyAndDateAndDept(companyId, today, departmentId).size()
            : leaveRequestRepository.findApprovedByCompanyAndDate(companyId, today).size();

        // Co mat thuc su: phai co checkIn, hoac override, hoac da approve voi snap hours > 0
        long present = todayAttendances.stream()
            .filter(a -> calcSvc.isActuallyPresent(a))
            .count();

        // LATE: dung workFlags neu da approved (nguon chinh xac nhat),
        // nguoc lai dung status == LATE duoc set luc check-in theo shift + tolerance
        long late = todayAttendances.stream()
            .filter(a -> calcSvc.isActuallyPresent(a) && calcSvc.isLate(a))
            .count();

        long absent = Math.max(0, totalEmployees - present - onLeave);

        List<DashboardDTO.AttendanceRow> attendanceRows = todayAttendances.stream()
            .limit(20)
            .map(a -> {
                Employee emp = a.getEmployee();
                List<AttendanceRequest> empRequests = requestsByEmployee.getOrDefault(emp.getId(), List.of());

                // Effective check-in: chon cai som hon giua actual va applied request
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

                // Neu override, uu tien override
                if (a.getOverrideCheckIn()  != null) effectiveIn  = a.getOverrideCheckIn();
                if (a.getOverrideCheckOut() != null) effectiveOut = a.getOverrideCheckOut();

                LocalDateTime displayIn  = effectiveIn  != null ? today.atTime(effectiveIn)  : null;
                LocalDateTime displayOut = effectiveOut != null ? today.atTime(effectiveOut) : null;

                boolean actuallyPresent = calcSvc.isActuallyPresent(a);
                return DashboardDTO.AttendanceRow.builder()
                    .employeeId(emp.getId())
                    .employeeCode(emp.getEmployeeCode())
                    .employeeName(emp.getFullName())
                    .departmentName(emp.getDepartment() != null ? emp.getDepartment().getName() : null)
                    .checkIn(actuallyPresent ? displayIn : null)
                    .checkOut(actuallyPresent ? displayOut : null)
                    .status(actuallyPresent ? a.getStatus().name() : Attendance.Status.ABSENT.name())
                    .late(actuallyPresent && calcSvc.isLate(a))
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

        // Shift assignments -- key: (employeeId, date) -> ShiftAssignment
        // Dung de lay ca tuong ung voi moi Attendance khi tinh trang thai
        List<com.bosskin.entity.ShiftAssignment> shiftAssignments =
            shiftAssignmentRepository.findByCompanyAndDateRange(companyId, from, to);
        // employeeId -> date -> ShiftAssignment (lay cai dau tien neu co nhieu ca)
        Map<Long, Map<LocalDate, com.bosskin.entity.ShiftAssignment>> shiftByEmpDate = new java.util.HashMap<>();
        for (com.bosskin.entity.ShiftAssignment sa : shiftAssignments) {
            shiftByEmpDate
                .computeIfAbsent(sa.getEmployee().getId(), k -> new java.util.HashMap<>())
                .putIfAbsent(sa.getWorkDate(), sa);
        }

        // Tien ich: tính trang thai hien thi tu Attendance va ShiftAssignment tuong ung
        // Dashboard khong load AttendanceRequest (qua nang) nen dung empty requests
        var emptyRequests = calcSvc.resolveRequests(List.of(), null, 0);

        java.util.function.Function<Attendance, Attendance.Status> deriveStatus = att -> {
            com.bosskin.entity.ShiftAssignment sa = shiftByEmpDate
                .getOrDefault(att.getEmployee().getId(), Map.of())
                .get(att.getDate());
            var shift = calcSvc.resolveShiftTimes(sa);
            var effectiveCheckIn = calcSvc.resolveEffectiveCheckIn(att, emptyRequests, shift);
            var policy = calcSvc.resolvePolicy(att.getEmployee());
            var flagCheckIn  = calcSvc.roundUp(
                att.getOverrideCheckIn() != null ? att.getOverrideCheckIn()
                    : (att.getCheckIn() != null ? att.getCheckIn().toLocalTime() : null),
                policy.roundingCheckInMinutes());
            var flagCheckOut = calcSvc.roundDown(
                att.getOverrideCheckOut() != null ? att.getOverrideCheckOut()
                    : (att.getCheckOut() != null ? att.getCheckOut().toLocalTime() : null),
                policy.roundingCheckOutMinutes());
            return calcSvc.deriveDisplayStatus(att, sa, effectiveCheckIn, flagCheckIn, flagCheckOut, shift, policy);
        };

        // Group by employee
        Map<Long, List<Attendance>> byEmployee = attendances.stream()
            .collect(Collectors.groupingBy(a -> a.getEmployee().getId()));

        long totalWorkDays = 0, totalLateDays = 0, totalAbsentDays = 0, totalLeaveDays = 0;

        List<DashboardDTO.RangeEmployeeRow> rows = new java.util.ArrayList<>();
        for (Map.Entry<Long, List<Attendance>> entry : byEmployee.entrySet()) {
            List<Attendance> empAtts = entry.getValue();
            Employee emp = empAtts.get(0).getEmployee();

            long present = empAtts.stream().filter(a -> deriveStatus.apply(a) == Attendance.Status.PRESENT).count();
            long late    = empAtts.stream().filter(a -> deriveStatus.apply(a) == Attendance.Status.LATE).count();
            long absent  = empAtts.stream().filter(a -> deriveStatus.apply(a) == Attendance.Status.ABSENT).count();
            long leave   = empAtts.stream().filter(a -> deriveStatus.apply(a) == Attendance.Status.LEAVE).count();

            totalWorkDays   += present + late;
            totalLateDays   += late;
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
                long p  = dayAtts.stream().filter(a -> deriveStatus.apply(a) == Attendance.Status.PRESENT).count();
                long l  = dayAtts.stream().filter(a -> deriveStatus.apply(a) == Attendance.Status.LATE).count();
                long ab = dayAtts.stream().filter(a -> deriveStatus.apply(a) == Attendance.Status.ABSENT).count();
                long lv = dayAtts.stream().filter(a -> deriveStatus.apply(a) == Attendance.Status.LEAVE).count();
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
        if (companyId == null) throw new org.springframework.web.server.ResponseStatusException(
            org.springframework.http.HttpStatus.BAD_REQUEST, "error.company.not_found");
        Company company = companyRepository.findById(companyId)
            .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.NOT_FOUND, "error.company.not_found"));
        LocalDate yearStart = LocalDate.of(year, 1, 1);
        LocalDate yearEnd   = LocalDate.of(year, 12, 31);

        // Salary trend 12 thang
        List<DashboardDTO.MonthlySalaryStat> salaryTrend = new ArrayList<>();
        var salaryTrendRows = departmentId != null
            ? payrollRepository.findMonthlySalaryTrendByDept(companyId, year, departmentId)
            : payrollRepository.findMonthlySalaryTrend(companyId, year);
        for (Object[] row : salaryTrendRows) {
            salaryTrend.add(DashboardDTO.MonthlySalaryStat.builder()
                .month(((Number) row[0]).intValue())
                .totalNetSalary(row[1] != null ? (BigDecimal) row[1] : BigDecimal.ZERO)
                .employeeCount(((Number) row[2]).longValue())
                .build());
        }

        // Attendance trend 90 ngay gan nhat
        LocalDate trendFrom = LocalDate.now().minusDays(89);
        LocalDate trendTo   = LocalDate.now();

        Map<LocalDate, List<Attendance>> attendanceByDate = (departmentId != null
            ? attendanceRepository.findByCompanyAndDateRangeAndDept(companyId, trendFrom, trendTo, departmentId)
            : attendanceRepository.findByCompanyAndDateRange(companyId, trendFrom, trendTo))
            .stream()
            .collect(Collectors.groupingBy(Attendance::getDate));

        // Shift assignments cho trend period -- de tinh absent dung (chi tinh khi co ca)
        List<com.bosskin.entity.ShiftAssignment> trendShifts =
            shiftAssignmentRepository.findByCompanyAndDateRange(companyId, trendFrom, trendTo);
        Map<Long, java.util.Set<LocalDate>> trendShiftDates = new java.util.HashMap<>();
        for (com.bosskin.entity.ShiftAssignment sa : trendShifts) {
            trendShiftDates.computeIfAbsent(sa.getEmployee().getId(), k -> new java.util.HashSet<>())
                           .add(sa.getWorkDate());
        }

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
            long present = dayAttendances.stream().filter(a -> calcSvc.isActuallyPresent(a) && !calcSvc.isLate(a)).count();
            long late    = dayAttendances.stream().filter(a -> calcSvc.isActuallyPresent(a) &&  calcSvc.isLate(a)).count();
            long absent  = dayAttendances.stream().filter(a -> {
                java.util.Set<LocalDate> sd = trendShiftDates.getOrDefault(a.getEmployee().getId(), java.util.Set.of());
                return calcSvc.isAbsent(a, sd.contains(a.getDate()));
            }).count();
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

        // Top 10 nhan vien di muon trong nam
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

        // Overall stats cho nam
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
            totalWorkDays += empAtts.stream().filter(a -> calcSvc.isActuallyPresent(a)).count();
            totalLate     += empAtts.stream().filter(a -> calcSvc.isActuallyPresent(a) && calcSvc.isLate(a)).count();
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
