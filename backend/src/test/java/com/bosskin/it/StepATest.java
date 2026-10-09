package com.bosskin.it;

import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** Kế hoạch khi chưa có AWS — bước A: các việc còn lại sau thử nghiệm nội bộ. */
class StepATest extends IntegrationTest {

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
