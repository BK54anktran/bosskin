package com.bosskin.service;

import com.bosskin.dto.DashboardDTO;
import com.bosskin.entity.Attendance;
import com.bosskin.entity.AttendanceRequest;
import com.bosskin.entity.Company;
import com.bosskin.entity.Employee;
import com.bosskin.entity.SalaryGrade;
import com.bosskin.entity.Payroll;
import com.bosskin.entity.User;
import java.time.LocalTime;
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
    private final ContractService contractService;
    private final DocumentService documentService;

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

        // Vắng = NV có ca hôm nay ĐÃ KẾT THÚC nhưng chưa có mặt và không nghỉ phép. NV không có ca (T7/CN, NV mới
        // chưa xếp ca) không tính là vắng — trước đây lấy tổng NV trừ có mặt trừ nghỉ. Ca chưa tới giờ / đang
        // diễn ra mà chưa check-in thì chưa tính vắng (13/10/2026).
        java.util.Set<Long> scheduled = shiftAssignmentRepository.findByCompanyAndDate(companyId, today).stream()
            .filter(sa -> departmentId == null || (sa.getEmployee().getDepartment() != null
                && departmentId.equals(sa.getEmployee().getDepartment().getId())))
            .filter(sa -> calcSvc.shiftEnded(today, calcSvc.resolveShiftTimes(sa)))
            .map(sa -> sa.getEmployee().getId())
            .collect(Collectors.toSet());
        java.util.Set<Long> presentIds = todayAttendances.stream()
            .filter(a -> calcSvc.isActuallyPresent(a))
            .map(a -> a.getEmployee().getId())
            .collect(Collectors.toSet());
        java.util.Set<Long> leaveIds = (departmentId != null
                ? leaveRequestRepository.findApprovedByCompanyAndDateAndDept(companyId, today, departmentId)
                : leaveRequestRepository.findApprovedByCompanyAndDate(companyId, today)).stream()
            .map(l -> l.getEmployee().getId())
            .collect(Collectors.toSet());
        long absent = scheduled.stream().filter(id -> !presentIds.contains(id) && !leaveIds.contains(id)).count();

        List<DashboardDTO.AttendanceRow> attendanceRows = todayAttendances.stream()
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

        DashboardDTO.RecentPayroll recentPayroll = latestPayroll(companyId, YearMonth.now());

        return DashboardDTO.Response.builder()
            .date(today)
            .todayStats(stats)
            .todayAttendance(attendanceRows)
            .recentPayroll(canSeeSalary(user) ? recentPayroll : null)
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
    /** Số liệu lương trên dashboard chỉ hiện cho người có quyền xem lương (S7). */
    private boolean canSeeSalary(User user) {
        return user.can("payroll.view");
    }

    public DashboardDTO.AnalyticsResponse getAnalytics(User user, Long departmentId, int year) {
        Long companyId = user.getCompanyId();
        if (companyId == null) throw new org.springframework.web.server.ResponseStatusException(
            org.springframework.http.HttpStatus.BAD_REQUEST, "error.company.not_found");
        Company company = companyRepository.findById(companyId)
            .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.NOT_FOUND, "error.company.not_found"));
        LocalDate yearStart = LocalDate.of(year, 1, 1);
        LocalDate yearEnd   = LocalDate.of(year, 12, 31);

        // Salary trend 12 thang — chỉ khi có quyền xem lương (S7)
        final boolean canSeeSalary = canSeeSalary(user);
        List<DashboardDTO.MonthlySalaryStat> salaryTrend = new ArrayList<>();
        List<Object[]> salaryTrendRows = !canSeeSalary ? List.of() : departmentId != null
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
                .estimatedCost(canSeeSalary ? estimated : null)
                .gradeBreakdown(canSeeSalary ? gradeBreakdown : List.of())
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


    // ── KPI Summary ────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public DashboardDTO.KpiResponse getKpi(User user, Long departmentId, LocalDate date) {
        Long companyId = user.getCompanyId();
        LocalDate today = date != null ? date : LocalDate.now();
        LocalDate monthStart = today.withDayOfMonth(1);
        LocalDate lastMonthStart = monthStart.minusMonths(1);
        LocalDate lastMonthEnd = monthStart.minusDays(1);

        long total = departmentId != null
            ? employeeRepository.countByCompanyIdAndDepartmentId(companyId, departmentId)
            : employeeRepository.countByCompanyId(companyId);

        long newHiresThis = employeeRepository.countJoinedBetween(companyId, monthStart, today, departmentId);
        long newHiresLast = employeeRepository.countJoinedBetween(companyId, lastMonthStart, lastMonthEnd, departmentId);
        long resignedThis  = employeeRepository.countResignedBetween(companyId, monthStart, today, departmentId);

        long totalAtMonthStart = Math.max(1, total + resignedThis - newHiresThis);
        double attritionRate = Math.round((double) resignedThis / totalAtMonthStart * 1000.0) / 10.0;

        List<Attendance> todayAtts = departmentId != null
            ? attendanceRepository.findByCompanyAndDateAndDept(companyId, today, departmentId)
            : attendanceRepository.findByCompanyAndDate(companyId, today);

        long onLeave = departmentId != null
            ? leaveRequestRepository.findApprovedByCompanyAndDateAndDept(companyId, today, departmentId).size()
            : leaveRequestRepository.findApprovedByCompanyAndDate(companyId, today).size();

        long todayPresent = todayAtts.stream().filter(a -> calcSvc.isActuallyPresent(a)).count();
        long todayLate    = todayAtts.stream().filter(a -> calcSvc.isActuallyPresent(a) && calcSvc.isLate(a)).count();
        // Vắng = NV có ca hôm nay chưa có mặt, không nghỉ phép (giống todayStats)
        java.util.Set<Long> kpiPresentIds = todayAtts.stream().filter(a -> calcSvc.isActuallyPresent(a))
            .map(a -> a.getEmployee().getId()).collect(Collectors.toSet());
        java.util.Set<Long> kpiScheduled = shiftAssignmentRepository.findByCompanyAndDate(companyId, today).stream()
            .filter(sa -> departmentId == null || (sa.getEmployee().getDepartment() != null
                && departmentId.equals(sa.getEmployee().getDepartment().getId())))
            .map(sa -> sa.getEmployee().getId()).collect(Collectors.toSet());
        long todayAbsent  = Math.max(0, kpiScheduled.stream().filter(id -> !kpiPresentIds.contains(id)).count() - onLeave);

        double attendanceRate = total > onLeave
            ? Math.round((double) todayPresent / (total - onLeave) * 1000.0) / 10.0
            : 0.0;

        DashboardDTO.RecentPayroll payroll = latestPayroll(companyId, YearMonth.from(today));

        return DashboardDTO.KpiResponse.builder()
            .totalActiveEmployees((int) total)
            .newHiresThisMonth((int) newHiresThis)
            .newHiresLastMonth((int) newHiresLast)
            .resignedThisMonth((int) resignedThis)
            .attritionRate(attritionRate)
            .todayPresent(todayPresent)
            .todayAbsent(todayAbsent)
            .todayOnLeave(onLeave)
            .todayLate(todayLate)
            .todayAttendanceRate(attendanceRate)
            .currentMonthPayroll(canSeeSalary(user) ? payroll.getTotalNetSalary() : null)
            .currentMonthPayrollCount(canSeeSalary(user) ? payroll.getEmployeeCount() : 0)
            .currentMonthPayrollStatus(canSeeSalary(user) ? payroll.getStatus() : null)
            .currentMonthPayrollYear(canSeeSalary(user) ? payroll.getYear() : null)
            .currentMonthPayrollMonth(canSeeSalary(user) ? payroll.getMonth() : null)
            .date(today)
            .build();
    }

    // ── Risk & Warnings ────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public DashboardDTO.RiskResponse getRisks(User user, Long departmentId, LocalDate date) {
        Long companyId = user.getCompanyId();
        LocalDate today = date != null ? date : LocalDate.now();
        LocalDate monthStart = today.withDayOfMonth(1);

        // 1. Repeated late this month (>= 3 occurrences)
        List<DashboardDTO.RepeatedLateRisk> repeatedLate = new ArrayList<>();
        for (Object[] row : attendanceRepository.findTopLateEmployees(
                companyId, monthStart, today, departmentId, PageRequest.of(0, 100))) {
            int late = ((Number) row[4]).intValue();
            if (late >= 3) {
                repeatedLate.add(DashboardDTO.RepeatedLateRisk.builder()
                    .employeeId(((Number) row[0]).longValue())
                    .employeeCode((String) row[1])
                    .employeeName((String) row[2])
                    .departmentName((String) row[3])
                    .lateDaysThisMonth(late)
                    .build());
            }
        }

        // 2. Checked in today but no checkout yet
        List<DashboardDTO.MissingCheckoutRisk> missingCheckout = new ArrayList<>();
        for (Attendance a : attendanceRepository.findMissingCheckout(companyId, today, departmentId)) {
            Employee emp = a.getEmployee();
            LocalTime cin = a.getCheckIn() != null ? a.getCheckIn().toLocalTime() : null;
            missingCheckout.add(DashboardDTO.MissingCheckoutRisk.builder()
                .employeeId(emp.getId())
                .employeeCode(emp.getEmployeeCode())
                .employeeName(emp.getFullName())
                .departmentName(emp.getDepartment() != null ? emp.getDepartment().getName() : null)
                .checkInTime(cin)
                .build());
        }

        // 3. Probation ending within 30 days (default probation = 60 days from joinDate)
        // probationEnd = joinDate + 60; want: today <= probationEnd <= today + 30
        // → joinDate between (today - 60) and (today - 30)
        List<DashboardDTO.ProbationEndingRisk> probationEnding = new ArrayList<>();
        for (Employee emp : employeeRepository.findActiveJoinedBetween(
                companyId, today.minusDays(60), today.minusDays(30), departmentId)) {
            LocalDate end = emp.getJoinDate().plusDays(60);
            int daysLeft = (int) (end.toEpochDay() - today.toEpochDay());
            if (daysLeft >= 0) {
                probationEnding.add(DashboardDTO.ProbationEndingRisk.builder()
                    .employeeId(emp.getId())
                    .employeeCode(emp.getEmployeeCode())
                    .employeeName(emp.getFullName())
                    .departmentName(emp.getDepartment() != null ? emp.getDepartment().getName() : null)
                    .joinDate(emp.getJoinDate())
                    .probationEnd(end)
                    .daysLeft(daysLeft)
                    .build());
            }
        }

        // 4. Active employees without salary grade (payroll not configured)
        List<DashboardDTO.NoSalaryGradeRisk> noSalaryGrade = new ArrayList<>();
        for (Employee emp : employeeRepository.findActiveMissingSalaryGrade(companyId, departmentId)) {
            noSalaryGrade.add(DashboardDTO.NoSalaryGradeRisk.builder()
                .employeeId(emp.getId())
                .employeeCode(emp.getEmployeeCode())
                .employeeName(emp.getFullName())
                .departmentName(emp.getDepartment() != null ? emp.getDepartment().getName() : null)
                .build());
        }

        // 5. Bước L: hợp đồng cần gia hạn (theo số ngày báo trước của công ty)
        List<DashboardDTO.ContractExpiringRisk> contractExpiring = new ArrayList<>();
        if (user.hasPermission("CONTRACT_VIEW")) {
            for (var c : contractService.expiring(companyId, user.getId(), null)) {
                if (departmentId != null && !departmentId.equals(c.getDepartmentId())) continue;
                contractExpiring.add(DashboardDTO.ContractExpiringRisk.builder()
                    .contractId(c.getId()).employeeId(c.getEmployeeId()).employeeCode(c.getEmployeeCode())
                    .employeeName(c.getEmployeeName()).departmentName(c.getDepartmentName())
                    .contractNo(c.getContractNo()).endDate(c.getEndDate())
                    .daysLeft(c.getDaysToEnd() != null ? c.getDaysToEnd() : 0)
                    .build());
            }
        }

        // 6. Bước N: tài liệu nhân sự sắp / đã hết hạn
        List<DashboardDTO.DocumentExpiringRisk> documentExpiring = new ArrayList<>();
        if (user.hasPermission(DocumentService.VIEW)) {
            for (var d : documentService.expiring(companyId, user.getId(), null)) {
                if (departmentId != null && !departmentId.equals(d.getDepartmentId())) continue;
                documentExpiring.add(DashboardDTO.DocumentExpiringRisk.builder()
                    .documentId(d.getId()).employeeId(d.getEmployeeId()).employeeCode(d.getEmployeeCode())
                    .employeeName(d.getEmployeeName()).departmentName(d.getDepartmentName())
                    .typeName(d.getTypeName()).expiresOn(d.getExpiresOn())
                    .daysLeft(d.getDaysToExpiry() != null ? d.getDaysToExpiry() : 0)
                    .build());
            }
        }

        int total = repeatedLate.size() + missingCheckout.size() + probationEnding.size() + noSalaryGrade.size()
            + contractExpiring.size() + documentExpiring.size();
        return DashboardDTO.RiskResponse.builder()
            .repeatedLate(repeatedLate)
            .missingCheckout(missingCheckout)
            .probationEnding(probationEnding)
            .noSalaryGrade(noSalaryGrade)
            .contractExpiring(contractExpiring)
            .documentExpiring(documentExpiring)
            .totalWarnings(total)
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

    /**
     * Kỳ lương hiển thị ở Tổng quan: kỳ gần nhất (12 tháng trở lại) đã chốt xong — có phiếu lương và không còn
     * phiếu nháp. Chưa có kỳ nào chốt xong → kỳ gần nhất có phiếu bất kỳ. Trước đây lấy tháng hiện tại dù
     * mới có 1 phiếu nháp.
     */
    private DashboardDTO.RecentPayroll latestPayroll(Long companyId, YearMonth from) {
        DashboardDTO.RecentPayroll firstAny = null;
        for (int i = 0; i < 12; i++) {
            YearMonth ym = from.minusMonths(i);
            long count = payrollRepository.countByCompanyAndMonth(companyId, ym.getYear(), ym.getMonthValue());
            if (count == 0) continue;
            DashboardDTO.RecentPayroll p = buildRecentPayroll(companyId, ym);
            boolean hasDraft = payrollRepository.findStatusSummaryByCompanyAndMonth(companyId, ym.getYear(), ym.getMonthValue())
                .stream().anyMatch(row -> row[0] == Payroll.Status.DRAFT);
            if (!hasDraft) return p;
            if (firstAny == null) firstAny = p;
        }
        return firstAny != null ? firstAny : buildRecentPayroll(companyId, from);
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
