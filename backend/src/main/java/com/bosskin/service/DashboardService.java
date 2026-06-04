package com.bosskin.service;

import com.bosskin.dto.DashboardDTO;
import com.bosskin.entity.Attendance;
import com.bosskin.entity.Employee;
import com.bosskin.entity.Payroll;
import com.bosskin.entity.User;
import com.bosskin.repository.AttendanceRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.LeaveRequestRepository;
import com.bosskin.repository.PayrollRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.YearMonth;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DashboardService {

    private static final LocalTime LATE_THRESHOLD = LocalTime.of(8, 30);

    private final EmployeeRepository employeeRepository;
    private final AttendanceRepository attendanceRepository;
    private final LeaveRequestRepository leaveRequestRepository;
    private final PayrollRepository payrollRepository;

    @Transactional(readOnly = true)
    public DashboardDTO.Response getDashboard(User user) {
        Long companyId = user.getCompanyId();
        LocalDate today = LocalDate.now();

        long totalEmployees = employeeRepository.countByCompanyId(companyId);
        List<Attendance> todayAttendances = attendanceRepository.findByCompanyAndDate(companyId, today);
        long onLeave = leaveRequestRepository.findApprovedByCompanyAndDate(companyId, today).size();

        long present = todayAttendances.stream()
            .filter(a -> a.getStatus() != Attendance.Status.ABSENT)
            .count();
        long late = todayAttendances.stream()
            .filter(a -> a.getCheckIn() != null && a.getCheckIn().toLocalTime().isAfter(LATE_THRESHOLD))
            .count();
        long absent = Math.max(0, totalEmployees - present - onLeave);

        List<DashboardDTO.AttendanceRow> attendanceRows = todayAttendances.stream()
            .limit(10)
            .map(a -> {
                boolean isLate = a.getCheckIn() != null && a.getCheckIn().toLocalTime().isAfter(LATE_THRESHOLD);
                Employee emp = a.getEmployee();
                return DashboardDTO.AttendanceRow.builder()
                    .employeeId(emp.getId())
                    .employeeCode(emp.getEmployeeCode())
                    .employeeName(emp.getFullName())
                    .departmentName(emp.getDepartment() != null ? emp.getDepartment().getName() : null)
                    .checkIn(a.getCheckIn())
                    .checkOut(a.getCheckOut())
                    .status(a.getStatus().name())
                    .late(isLate)
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

        // Payroll: tháng hiện tại hoặc tháng trước nếu chưa generate
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
