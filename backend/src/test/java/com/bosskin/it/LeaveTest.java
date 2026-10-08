package com.bosskin.it;

import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.LeaveGrantRepository;
import com.bosskin.service.LeaveService;
import com.bosskin.support.Fixture;
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

    @Test
    @DisplayName("F9 · Danh sách đơn phân trang + tìm kiếm phía server; nhân viên chỉ thấy đơn của mình")
    void requestList_serverPaging() {
        var c = fixture.standardCompany();
        String kl = String.valueOf(c.leaveTypes.get("KL"));
        for (int i = 5; i <= 9; i++) {
            var e = c.emp(i);
            api.post(c.tokenOf(e), "/api/v1/leaves/requests",
                dayLeave(Long.parseLong(kl), "2026-11-1" + i, "2026-11-1" + i)).expectOk();
        }
        String manager = c.tokenOf(c.emp(1));

        var p0 = api.get(manager, "/api/v1/leaves/requests/page?page=0&size=2").expectOk().body();
        assertThat(p0.path("totalElements").asInt()).isEqualTo(5);
        assertThat(p0.path("content").size()).isEqualTo(2);
        var p2 = api.get(manager, "/api/v1/leaves/requests/page?page=2&size=2").expectOk().body();
        assertThat(p2.path("content").size()).isEqualTo(1);

        var byName = api.get(manager, "/api/v1/leaves/requests/page?q=hung").expectOk().body();
        assertThat(byName.path("totalElements").asInt()).as("tìm không dấu 'hung' ra Đặng Văn Hùng").isEqualTo(1);

        var mine = api.get(c.tokenOf(c.emp(6)), "/api/v1/leaves/requests/page").expectOk().body();
        assertThat(mine.path("totalElements").asInt()).isEqualTo(1);
        assertThat(mine.path("content").get(0).path("employeeId").asLong()).isEqualTo(c.emp(6).id());
    }

    private double usedDays(Fixture.TestCompany c, Fixture.Emp e, String validTo) {
        for (var g : api.get(c.adminToken, "/api/v1/leaves/grants?employeeId=" + e.id()).expectOk().body()) {
            if (validTo.equals(g.path("validTo").asText())) return g.path("usedDays").asDouble();
        }
        throw new AssertionError("không thấy quỹ hết hạn " + validTo);
    }

    @Test
    @DisplayName("Quỹ phép tách theo loại: quỹ loại nào dùng cho loại đó, quỹ chung dùng cho mọi loại")
    void leavePools_areSeparatedByType() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        long pb = c.createLeaveType("PB", "Phép bù", true);
        c.grantLeaveDays(e, "PN", 5);
        String token = c.tokenOf(e);

        assertThat(api.post(token, "/api/v1/leaves/requests", dayLeave(pb, "2026-11-02", "2026-11-02")).status())
            .as("quỹ PN không dùng cho PB").isEqualTo(400);

        api.post(c.adminToken, "/api/v1/leaves/grants/manual", Map.of(
            "employeeId", e.id(), "grantDays", 1, "validFrom", "2020-01-01", "validTo", "2099-12-30",
            "note", "Quỹ chung")).expectOk();
        assertThat(api.post(token, "/api/v1/leaves/requests", dayLeave(pb, "2026-11-02", "2026-11-02")).status())
            .as("quỹ chung dùng được").isEqualTo(201);
        assertThat(api.post(token, "/api/v1/leaves/requests", dayLeave(pb, "2026-11-03", "2026-11-03")).status())
            .as("quỹ chung đã hết").isEqualTo(400);
        assertThat(api.post(token, "/api/v1/leaves/requests",
            dayLeave(c.leaveTypes.get("PN"), "2026-11-09", "2026-11-13")).status())
            .as("PN vẫn đủ 5 ngày").isEqualTo(201);
    }

    @Test
    @DisplayName("L13 · Hoàn phép theo sổ: trả đúng quỹ đã trừ, huỷ một ngày của đơn nhiều ngày hoàn đúng một ngày")
    void ledger_refundsExactGrants() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.grantLeaveDays(e, "PN", 5); // hết hạn 2099-12-31
        api.post(c.adminToken, "/api/v1/leaves/grants/manual", Map.of(
            "employeeId", e.id(), "leaveTypeId", c.leaveTypes.get("PN"), "grantDays", 1,
            "validFrom", "2020-01-01", "validTo", "2026-12-31", "note", "Sắp hết hạn")).expectOk();
        String token = c.tokenOf(e);

        var group = api.post(token, "/api/v1/leaves/requests",
            dayLeave(c.leaveTypes.get("PN"), "2026-11-16", "2026-11-18")).expectOk();
        assertThat(usedDays(c, e, "2026-12-31")).as("quỹ sắp hết hạn trừ trước").isEqualTo(1.0);
        assertThat(usedDays(c, e, "2099-12-31")).isEqualTo(2.0);

        long lastChild = -1;
        for (var ch : group.body().path("children")) {
            if ("2026-11-18".equals(ch.path("fromDate").asText())) lastChild = ch.path("id").asLong();
        }
        api.post(token, "/api/v1/leaves/requests/" + lastChild + "/cancel", null).expectOk();
        assertThat(usedDays(c, e, "2099-12-31")).as("hoàn 1 ngày vào quỹ trừ sau cùng").isEqualTo(1.0);
        assertThat(usedDays(c, e, "2026-12-31")).isEqualTo(1.0);

        api.put(c.tokenOf(c.emp(1)), "/api/v1/leaves/requests/" + group.id() + "/reject", Map.of()).expectOk();
        assertThat(usedDays(c, e, "2099-12-31")).isEqualTo(0.0);
        assertThat(usedDays(c, e, "2026-12-31")).isEqualTo(0.0);

        var ledger = api.get(token, "/api/v1/leaves/ledger?employeeId=" + e.id()).expectOk().body();
        long deducts = 0, refunds = 0;
        for (var row : ledger) { if ("DEDUCT".equals(row.path("kind").asText())) deducts++; else refunds++; }
        assertThat(deducts).isEqualTo(2);
        assertThat(refunds).isEqualTo(3);
    }
}
