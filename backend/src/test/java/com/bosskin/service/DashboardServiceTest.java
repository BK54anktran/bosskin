package com.bosskin.service;

import com.bosskin.entity.Attendance;
import com.bosskin.entity.Company;
import com.bosskin.entity.Department;
import com.bosskin.entity.Employee;
import com.bosskin.entity.Position;
import com.bosskin.entity.SalaryGrade;
import com.bosskin.entity.User;
import com.bosskin.repository.AttendanceRepository;
import com.bosskin.repository.AttendanceRequestRepository;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.LeaveRequestRepository;
import com.bosskin.repository.PayrollRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DashboardServiceTest {

    @Mock private EmployeeRepository employeeRepository;
    @Mock private AttendanceRepository attendanceRepository;
    @Mock private AttendanceRequestRepository attendanceRequestRepository;
    @Mock private LeaveRequestRepository leaveRequestRepository;
    @Mock private CompanyRepository companyRepository;
    @Mock private PayrollRepository payrollRepository;
    @Mock private AttendanceCalculationService calcSvc;

    @InjectMocks private DashboardService service;

    @Test
    void getAnalytics_usesSalaryGradeForEstimatedCost_withoutPayrollData() {
        Company company = Company.builder()
            .id(10L)
            .name("Bosskin")
            .code("BK")
            .standardWorkDays(22)
            .leaveHoursPerDay(new BigDecimal("8"))
            .build();
        Department department = Department.builder()
            .id(20L)
            .company(company)
            .name("HR")
            .code("HR")
            .build();
        Position position = Position.builder()
            .id(30L)
            .department(department)
            .name("Staff")
            .code("ST")
            .build();
        SalaryGrade gradeA = SalaryGrade.builder()
            .id(40L)
            .department(department)
            .code("A1")
            .name("Grade A")
            .baseRate(new BigDecimal("11000000"))
            .build();
        SalaryGrade gradeB = SalaryGrade.builder()
            .id(41L)
            .department(department)
            .code("B1")
            .name("Grade B")
            .baseRate(new BigDecimal("22000000"))
            .build();
        Employee employeeA = buildEmployee(100L, company, department, position, gradeA, "EMP-A");
        Employee employeeB = buildEmployee(101L, company, department, position, gradeB, "EMP-B");

        Attendance attendanceA = Attendance.builder()
            .id(1000L)
            .employee(employeeA)
            .date(LocalDate.of(2026, 6, 1))
            .snapActualHours(4.0)
            .status(Attendance.Status.PRESENT)
            .approved(true)
            .build();
        Attendance attendanceB = Attendance.builder()
            .id(1001L)
            .employee(employeeB)
            .date(LocalDate.of(2026, 6, 1))
            .snapActualHours(4.0)
            .status(Attendance.Status.PRESENT)
            .approved(true)
            .build();

        User user = User.builder()
            .id(1L)
            .companyId(10L)
            .company(company)
            .build();

        when(companyRepository.findById(10L)).thenReturn(Optional.of(company));
        when(payrollRepository.findMonthlySalaryTrend(eq(10L), eq(2026))).thenReturn(List.of());
        when(attendanceRepository.findByCompanyAndDateRange(eq(10L), any(LocalDate.class), any(LocalDate.class)))
            .thenReturn(List.of(attendanceA, attendanceB));
        when(attendanceRepository.findDailyAttendanceSummary(eq(10L), any(LocalDate.class), any(LocalDate.class), isNull()))
            .thenReturn(List.of(new Object[]{LocalDate.of(2026, 6, 1), 2L, 0L, 0L, 8.0d}));
        when(attendanceRepository.findTopLateEmployees(eq(10L), any(LocalDate.class), any(LocalDate.class), isNull(), any(Pageable.class)))
            .thenReturn(List.of());
        when(employeeRepository.countByCompanyId(10L)).thenReturn(2L);

        var response = service.getAnalytics(user, null, 2026);

        assertEquals(1, response.getAttendanceTrend().size());
        assertEquals(16500000d, response.getAttendanceTrend().get(0).getEstimatedCost().doubleValue());
        assertEquals(8.0d, response.getAttendanceTrend().get(0).getTotalHours());
    }

    private Employee buildEmployee(
        Long id,
        Company company,
        Department department,
        Position position,
        SalaryGrade grade,
        String code
    ) {
        return Employee.builder()
            .id(id)
            .company(company)
            .employeeCode(code)
            .fullName(code)
            .email(code.toLowerCase() + "@example.com")
            .gender(Employee.Gender.MALE)
            .joinDate(LocalDate.of(2024, 1, 1))
            .department(department)
            .position(position)
            .salaryGrade(grade)
            .build();
    }
}
