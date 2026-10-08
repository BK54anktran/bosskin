package com.bosskin.it.knownbugs;

import com.bosskin.entity.Attendance;
import com.bosskin.entity.Payroll;
import com.bosskin.entity.SalaryFormula;
import com.bosskin.repository.AttendanceRepository;
import com.bosskin.service.PayrollService;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tái hiện lỗi nghỉ phép / bảng lương / rò dữ liệu lương đã biết.
 * Mỗi test khẳng định hành vi ĐÚNG nên hiện đang đỏ.
 */
class LeavePayrollKnownBugsTest extends IntegrationTest {

    private static final LocalDate DAY = LocalDate.of(2026, 11, 3);

    @Autowired AttendanceRepository attendanceRepository;
    @Autowired PayrollService payrollService;

    @Test
    @DisplayName("L1 · Ngày nghỉ phép có lương đã duyệt được ghi công là LEAVE, không phải vắng")
    void l1_approvedPaidLeaveDay_isLeaveNotAbsent() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        long saId = c.assign(e, "HC", DAY);
        c.grantLeaveDays(e, "PN", 5);

        long leaveId = api.post(c.tokenOf(e), "/api/v1/leaves/requests", Map.of(
            "leaveTypeId", c.leaveTypes.get("PN"), "mode", "DAY_RANGE",
            "fromDate", DAY.toString(), "toDate", DAY.toString(), "reason", "Việc gia đình"))
            .expectOk().id();
        api.put(c.tokenOf(c.emp(1)), "/api/v1/leaves/requests/" + leaveId + "/approve", Map.of()).expectOk();

        api.post(c.adminToken, "/api/v1/attendances/approve", Map.of(
            "employeeId", e.id(), "date", DAY.toString(), "shiftAssignmentId", saId)).expectOk();

        Attendance att = attendanceRepository.findByEmployeeIdAndDate(e.id(), DAY).get(0);
        assertThat(att.getStatus()).isEqualTo(Attendance.Status.LEAVE);
    }

    @Test
    @DisplayName("L8 · Nghỉ không lương không cần số dư phép")
    void l8_unpaidLeave_doesNotRequireBalance() {
        var c = fixture.standardCompany();

        var res = api.post(c.tokenOf(c.emp(6)), "/api/v1/leaves/requests", Map.of(
            "leaveTypeId", c.leaveTypes.get("KL"), "mode", "DAY_RANGE",
            "fromDate", DAY.toString(), "toDate", DAY.toString(), "reason", "Việc riêng"));

        assertThat(res.status()).as(res.raw()).isEqualTo(201);
    }

    @Test
    @DisplayName("L3 · Công thức dùng STANDARD_WORK_DAYS tạo được bảng lương")
    void l3_formulaUsingStandardWorkDays_generates() {
        var c = fixture.standardCompany();
        SalaryFormula formula = SalaryFormula.builder()
            .name("Test STANDARD_WORK_DAYS")
            .expressionGross("STANDARD_WORK_DAYS * 1000")
            .expressionNet("GROSS")
            .build();

        Payroll p = payrollService.generatePayrollWithFormula(c.emp(6).id(), 2026, 10, formula);

        assertThat(p.getGrossSalary()).isNotNull().isGreaterThan(BigDecimal.ZERO);
    }

    @Test
    @DisplayName("S7 · Người không có quyền xem lương không thấy tổng lương trên Dashboard")
    void s7_dashboardHidesSalaryWithoutPayrollView() {
        var c = fixture.standardCompany();
        SalaryFormula formula = SalaryFormula.builder()
            .name("Lương cố định")
            .expressionGross("5000000")
            .expressionNet("GROSS")
            .build();
        payrollService.generatePayrollWithFormula(c.emp(6).id(), 2026, 10, formula);

        c.createRole("Trưởng nhóm", List.of("DASHBOARD_VIEW"));
        var lead = c.emp(5);
        c.setRole(lead, "Trưởng nhóm");

        var res = api.get(c.tokenOf(lead), "/api/v1/dashboard/analytics?year=2026").expectOk();

        var trend = res.body().path("salaryTrend");
        boolean leaks = false;
        for (var m : trend) {
            if (m.path("totalNetSalary").asDouble(0) > 0) leaks = true;
        }
        assertThat(leaks).as("salaryTrend lộ tổng lương: %s", trend).isFalse();
    }
}
