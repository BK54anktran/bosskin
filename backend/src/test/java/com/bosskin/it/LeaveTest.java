package com.bosskin.it;

import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.LeaveGrantRepository;
import com.bosskin.service.LeaveService;
import com.bosskin.support.IntegrationTest;
import org.springframework.beans.factory.annotation.Autowired;
import java.time.LocalDate;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.LinkedHashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** Nghỉ phép (Mốc 3a: L8, L9, L11, L12). */
class LeaveTest extends IntegrationTest {

    @Autowired LeaveService leaveService;
    @Autowired EmployeeRepository employeeRepository;
    @Autowired LeaveGrantRepository leaveGrantRepository;

    private Map<String, Object> dayLeave(long typeId, String from, String to) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("leaveTypeId", typeId);
        m.put("mode", "DAY_RANGE");
        m.put("fromDate", from);
        m.put("toDate", to);
        m.put("reason", "Việc riêng");
        return m;
    }

    @Test
    @DisplayName("L11 · Không xin 2 đơn nghỉ chồng ngày")
    void overlappingRequests_areRejected() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.grantLeaveDays(e, "PN", 10);
        String token = c.tokenOf(e);

        api.post(token, "/api/v1/leaves/requests", dayLeave(c.leaveTypes.get("PN"), "2026-11-10", "2026-11-12")).expectOk();
        var dup = api.post(token, "/api/v1/leaves/requests", dayLeave(c.leaveTypes.get("KL"), "2026-11-12", "2026-11-13"));

        assertThat(dup.status()).isEqualTo(409);
    }

    @Test
    @DisplayName("L12 · Loại phép theo ngày không nhận đơn theo giờ")
    void dayTypeWithHourMode_isRejected() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.grantLeaveDays(e, "PN", 10);
        Map<String, Object> body = dayLeave(c.leaveTypes.get("PN"), "2026-11-10", "2026-11-10");
        body.put("mode", "HOUR_RANGE");
        body.put("fromTime", "08:00");
        body.put("toTime", "12:00");

        assertThat(api.post(c.tokenOf(e), "/api/v1/leaves/requests", body).status()).isEqualTo(400);
    }

    @Test
    @DisplayName("L9 · Nhân viên không tự huỷ đơn đã duyệt; người duyệt huỷ được và hoàn phép")
    void cancelApproved_onlyByApprover() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.grantLeaveDays(e, "PN", 5);
        String token = c.tokenOf(e);
        long id = api.post(token, "/api/v1/leaves/requests",
            dayLeave(c.leaveTypes.get("PN"), "2026-11-10", "2026-11-10")).expectOk().id();
        String approver = c.tokenOf(c.emp(1));
        api.put(approver, "/api/v1/leaves/requests/" + id + "/approve", Map.of()).expectOk();

        assertThat(api.post(token, "/api/v1/leaves/requests/" + id + "/cancel", null).status()).isEqualTo(409);
        assertThat(api.post(approver, "/api/v1/leaves/requests/" + id + "/cancel", null).status()).isEqualTo(200);

        // Sau khi huỷ, xin lại đủ 5 ngày được (phép đã hoàn)
        assertThat(api.post(token, "/api/v1/leaves/requests",
            dayLeave(c.leaveTypes.get("PN"), "2026-11-16", "2026-11-20")).status()).isEqualTo(201);
    }

    @Test
    @DisplayName("L8 · Nghỉ không lương không trừ quỹ phép năm")
    void unpaidLeave_doesNotConsumeAnnualBalance() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.grantLeaveDays(e, "PN", 2);
        String token = c.tokenOf(e);

        api.post(token, "/api/v1/leaves/requests", dayLeave(c.leaveTypes.get("KL"), "2026-11-02", "2026-11-04")).expectOk();

        // Quỹ phép năm vẫn đủ 2 ngày
        assertThat(api.post(token, "/api/v1/leaves/requests",
            dayLeave(c.leaveTypes.get("PN"), "2026-11-10", "2026-11-11")).status()).isEqualTo(201);
    }

    @Test
    @DisplayName("L10 · Cộng phép ngày 31 chạy vào cuối tháng 30 ngày; thâm niên đủ năm; bỏ qua NV nghỉ việc; chạy lại không cộng trùng")
    void accrual_rules() {
        var c = fixture.standardCompany();
        var senior = c.emp(6);   // vào 2025-01-01 → đủ 1 năm vào 30/11/2026
        var junior = c.emp(7);
        var inactive = c.emp(8);
        api.put(c.adminToken, "/api/v1/employees/" + junior.id(), Map.of("joinDate", "2025-12-15")).expectOk();
        api.put(c.adminToken, "/api/v1/employees/" + inactive.id(), Map.of("status", "INACTIVE")).expectOk();

        Map<String, Object> rule = new LinkedHashMap<>();
        rule.put("name", "Phép năm thâm niên");
        rule.put("grantDays", 1);
        rule.put("frequency", "MONTHLY");
        rule.put("dayOfMonth", 31);
        rule.put("minTenureYears", 1);
        rule.put("active", true);
        api.post(c.adminToken, "/api/v1/leaves/accrual-rules", rule).expectOk();

        LocalDate nov30 = LocalDate.of(2026, 11, 30);
        assertThat(leaveService.runAccrualForCompany(c.id, nov30).get("created"))
            .as("10 NV trừ 1 NV chưa đủ thâm niên và 1 NV nghỉ việc").isEqualTo(8);
        assertThat(leaveService.runAccrualForCompany(c.id, nov30).get("created")).as("chạy lại").isZero();
        assertThat(leaveService.runAccrualForCompany(c.id, LocalDate.of(2026, 11, 29)).get("created"))
            .as("chưa tới ngày").isZero();
    }
}
