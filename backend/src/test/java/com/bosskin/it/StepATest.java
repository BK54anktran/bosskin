package com.bosskin.it;

import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** Kế hoạch khi chưa có AWS — bước A: các việc còn lại sau thử nghiệm nội bộ. */
class StepATest extends IntegrationTest {

    @org.springframework.beans.factory.annotation.Autowired com.bosskin.repository.AttendanceRepository attendanceRepository;

    @Test
    @DisplayName("Duyệt hàng loạt cả phòng cả tháng: duyệt mọi phân ca, bỏ qua công của chính mình, chạy lại không duyệt trùng")
    void bulkApprove_departmentMonth() {
        var c = fixture.standardCompany();
        var manager = c.emp(1); // Quản lý chấm công (phòng BGD)
        for (int i = 2; i <= 6; i++) {
            LocalDate d = LocalDate.of(2026, 11, i);
            c.assign(c.emp(6), "HC", d);
            c.assign(c.emp(7), "HC", d);
            c.assign(manager, "HC", d);
        }
        String token = c.tokenOf(manager);
        clock.set(java.time.LocalDateTime.of(2026, 12, 1, 9, 0)); // cả tháng 11 đã qua
        Map<String, Object> body = Map.of("from", "2026-11-01", "to", "2026-11-30",
            "departmentId", c.departments.get("SX"));

        var res = api.post(token, "/api/v1/attendances/approve-bulk", body).expectOk().body();
        assertThat(res.path("approved").asInt()).isEqualTo(10);
        assertThat(res.path("failed").asInt()).isZero();

        var again = api.post(token, "/api/v1/attendances/approve-bulk", body).expectOk().body();
        assertThat(again.path("approved").asInt()).isZero();
        assertThat(again.path("alreadyApproved").asInt()).isEqualTo(10);

        // Cả công ty: công của chính quản lý không được tự duyệt
        var all = api.post(token, "/api/v1/attendances/approve-bulk",
            Map.of("from", "2026-11-01", "to", "2026-11-30")).expectOk().body();
        assertThat(all.path("approved").asInt()).isZero();

        assertThat(api.get(c.adminToken, "/api/v1/audit-logs?action=ATTENDANCE_BULK_APPROVE")
            .expectOk().body().path("content")).hasSize(3);
    }

    @Test
    @DisplayName("Duyệt cả kỳ: bỏ qua hôm nay/tương lai (chưa hết ngày) và dòng chấm thiếu giờ ra; dòng đủ ngày trước vẫn duyệt")
    void bulkApprove_skipsTodayAndIncompletePunches() {
        var c = fixture.standardCompany();
        var manager = c.emp(1);
        var a = c.emp(6);
        var b = c.emp(7);
        LocalDate d2 = LocalDate.of(2026, 11, 2), d3 = LocalDate.of(2026, 11, 3), d4 = LocalDate.of(2026, 11, 4);
        for (LocalDate d : List.of(d2, d3, d4)) { c.assign(a, "HC", d); c.assign(b, "HC", d); }

        // 02/11: A chấm đủ vào/ra; B chỉ chấm vào (quên chấm ra)
        clock.set(d2.atTime(7, 55));
        assertThat(api.post(c.tokenOf(a), "/api/v1/attendances/self/check-in", Map.of()).status()).isEqualTo(201);
        assertThat(api.post(c.tokenOf(b), "/api/v1/attendances/self/check-in", Map.of()).status()).isEqualTo(201);
        clock.set(d2.atTime(17, 5));
        api.post(c.tokenOf(a), "/api/v1/attendances/self/check-out", Map.of()).expectOk();
        // Hôm nay 04/11 10:00: A mới chấm vào, ca chưa kết thúc
        clock.set(d4.atTime(7, 58));
        assertThat(api.post(c.tokenOf(a), "/api/v1/attendances/self/check-in", Map.of()).status()).isEqualTo(201);
        clock.set(d4.atTime(10, 0));

        var res = api.post(c.tokenOf(manager), "/api/v1/attendances/approve-bulk", Map.of(
            "from", "2026-11-01", "to", "2026-11-30", "departmentId", c.departments.get("SX"))).expectOk().body();
        // Duyệt: A 02/11 (đủ), A 03/11 + B 03/11 (vắng, ngày đã qua) = 3; B 02/11 chấm thiếu; 04/11 → 30/11 chưa qua
        assertThat(res.path("approved").asInt()).isEqualTo(3);
        assertThat(res.path("incomplete").asInt()).isEqualTo(1);
        assertThat(res.path("notEnded").asInt()).isEqualTo(2);
        assertThat(attendanceRepository.findByEmployeeIdAndDate(a.id(), d4)).allMatch(x -> !x.isApproved());
        assertThat(attendanceRepository.findByEmployeeIdAndDate(b.id(), d2)).allMatch(x -> !x.isApproved());
        assertThat(attendanceRepository.findByEmployeeIdAndDate(a.id(), d2)).anyMatch(x -> x.isApproved() && x.getSnapActualHours() != null && x.getSnapActualHours() > 0);
    }

    private long hourLeaveType(com.bosskin.support.Fixture.TestCompany c) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("code", "PG");
        body.put("name", "Phép giờ");
        body.put("unit", "HOUR");
        body.put("deductPerDay", 1);
        body.put("paid", true);
        body.put("requiresBalance", false);
        body.put("active", true);
        return api.post(c.adminToken, "/api/v1/leaves/types", body).expectOk().id();
    }

    @Test
    @DisplayName("L11 · Nghỉ theo giờ trừ phần trùng giờ nghỉ trưa của ca; nghỉ hẳn trong giờ nghỉ bị từ chối")
    void hourLeave_excludesLunchBreak() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.assign(e, "HC", LocalDate.of(2026, 11, 2)); // HC 08:00–17:00, nghỉ 12:00–13:00
        long pg = hourLeaveType(c);
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("leaveTypeId", pg);
        body.put("mode", "HOUR_RANGE");
        body.put("fromDate", "2026-11-02");
        body.put("toDate", "2026-11-02");
        body.put("fromTime", "10:00");
        body.put("toTime", "15:00");
        body.put("reason", "Khám bệnh");
        var res = api.post(c.tokenOf(e), "/api/v1/leaves/requests", body).expectOk();
        assertThat(res.body().path("requestedAmount").asDouble()).isEqualTo(4.0);

        api.post(c.tokenOf(e), "/api/v1/leaves/requests/" + res.id() + "/cancel", null).expectOk();
        body.put("fromTime", "12:00");
        body.put("toTime", "13:00");
        var lunch = api.post(c.tokenOf(e), "/api/v1/leaves/requests", body);
        assertThat(lunch.status()).isEqualTo(400);
        assertThat(lunch.raw()).contains("error.leave.within_break");
    }

    @Test
    @DisplayName("L11 · Đơn nghỉ 1 ngày vào ngày không có ca (NV đã có lịch quanh đó) bị từ chối")
    void singleDayLeave_onDayWithoutShift_isRejected() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.grantLeaveDays(e, "PN", 5);
        c.assign(e, "HC", LocalDate.of(2026, 11, 2));
        c.assign(e, "HC", LocalDate.of(2026, 11, 4));
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("leaveTypeId", c.leaveTypes.get("PN"));
        body.put("mode", "DAY_RANGE");
        body.put("fromDate", "2026-11-03");
        body.put("toDate", "2026-11-03");
        body.put("reason", "Việc riêng");
        var res = api.post(c.tokenOf(e), "/api/v1/leaves/requests", body);
        assertThat(res.status()).isEqualTo(400);
        assertThat(res.raw()).contains("error.leave.no_shift_days");

        body.put("fromDate", "2026-11-04");
        body.put("toDate", "2026-11-04");
        assertThat(api.post(c.tokenOf(e), "/api/v1/leaves/requests", body).status()).isEqualTo(201);
    }

    @Test
    @DisplayName("Tổng quan: ô lương lấy kỳ gần nhất đã chốt, không lấy tháng mới có phiếu nháp")
    void dashboard_latestClosedPayroll() {
        var c = fixture.standardCompany();
        long formula = api.post(c.adminToken, "/api/v1/salary-formulas", Map.of(
            "salaryGradeId", c.salaryGrades.get("NGAY300"), "name", "Cố định",
            "effectiveDate", "2026-01-01", "expressionGross", "10000000", "expressionNet", "GROSS")).expectOk().id();
        long oct = api.post(c.adminToken, "/api/v1/payrolls/generate", Map.of(
            "employeeId", c.emp(6).id(), "year", 2026, "month", 10, "formulaId", formula)).expectOk().id();
        api.post(c.adminToken, "/api/v1/payrolls/" + oct + "/approve", null).expectOk();
        api.post(c.adminToken, "/api/v1/payrolls/generate", Map.of(
            "employeeId", c.emp(7).id(), "year", 2026, "month", 11, "formulaId", formula)).expectOk();

        var kpi = api.get(c.adminToken, "/api/v1/dashboard/kpi?date=2026-11-15").expectOk().body();
        assertThat(kpi.path("currentMonthPayrollMonth").asInt()).isEqualTo(10);
        assertThat(kpi.path("currentMonthPayrollStatus").asText()).isEqualTo("APPROVED");
    }
}
