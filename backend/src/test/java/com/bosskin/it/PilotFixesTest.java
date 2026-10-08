package com.bosskin.it;

import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** Hồi quy cho các lỗi tìm thấy khi chạy thử nội bộ (pilot) 08–09/10/2026. */
class PilotFixesTest extends IntegrationTest {

    @Test
    @DisplayName("Duyệt công ngày không có ca và chưa có dữ liệu bị từ chối (không tạo bản ghi vắng); ngày có ca vẫn duyệt được")
    void approveDayWithoutShift_isRejected() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        LocalDate shiftDay = LocalDate.of(2026, 11, 2);
        c.assign(e, "HC", shiftDay);

        var noShift = api.post(c.adminToken, "/api/v1/attendances/approve", Map.of(
            "employeeId", e.id(), "date", "2026-11-01"));
        assertThat(noShift.status()).isEqualTo(400);
        assertThat(noShift.raw()).contains("error.attendance.nothing_to_approve");

        var timesheet = api.get(c.adminToken, "/api/v1/attendances/timesheet?employeeId=" + e.id() + "&year=2026&month=11")
            .expectOk().body();
        Long saId = null;
        for (var row : timesheet) {
            if ("2026-11-02".equals(row.path("date").asText())) saId = row.path("shiftAssignmentId").asLong();
        }
        assertThat(api.post(c.adminToken, "/api/v1/attendances/approve", Map.of(
            "employeeId", e.id(), "date", "2026-11-02", "shiftAssignmentId", saId)).status()).isEqualTo(200);
    }

    @Test
    @DisplayName("Kế toán không tự duyệt / sửa / trả bảng lương của chính mình")
    void accountantCannotProcessOwnPayroll() {
        var c = fixture.standardCompany();
        var accountantEmp = c.emp(2);
        String accountant = c.tokenOf(accountantEmp);
        long formula = api.post(c.adminToken, "/api/v1/salary-formulas", Map.of(
            "salaryGradeId", c.salaryGrades.get("NGAY300"), "name", "Cố định",
            "effectiveDate", "2026-01-01", "expressionGross", "10000000", "expressionNet", "GROSS")).expectOk().id();
        long own = api.post(accountant, "/api/v1/payrolls/generate", Map.of(
            "employeeId", accountantEmp.id(), "year", 2026, "month", 11, "formulaId", formula)).expectOk().id();

        var approve = api.post(accountant, "/api/v1/payrolls/" + own + "/approve", null);
        assertThat(approve.status()).isEqualTo(403);
        assertThat(approve.raw()).contains("error.payroll.cannot_process_own");
        assertThat(api.patch(accountant, "/api/v1/payrolls/" + own, Map.of("bonus", 1_000_000)).status()).isEqualTo(403);

        assertThat(api.post(c.adminToken, "/api/v1/payrolls/" + own + "/approve", null).status()).isEqualTo(200);
    }

    @Test
    @DisplayName("L11 · Đơn nghỉ nhiều ngày chỉ tính ngày có ca (bỏ T7, CN khi NV đã được xếp ca)")
    void multiDayLeave_countsOnlyShiftDays() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.grantLeaveDays(e, "PN", 5);
        // Thứ 6 13/11 và thứ 2 16/11 có ca; T7, CN không có ca
        c.assign(e, "HC", LocalDate.of(2026, 11, 13));
        c.assign(e, "HC", LocalDate.of(2026, 11, 16));
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("leaveTypeId", c.leaveTypes.get("PN"));
        body.put("mode", "DAY_RANGE");
        body.put("fromDate", "2026-11-13");
        body.put("toDate", "2026-11-16");
        body.put("reason", "Về quê");

        var res = api.post(c.tokenOf(e), "/api/v1/leaves/requests", body).expectOk();
        assertThat(res.body().path("requestedAmount").asDouble()).isEqualTo(2.0);
        assertThat(res.body().path("children")).hasSize(2);

    }

    @Test
    @DisplayName("Báo cáo cần quyền xem module; phạm vi phòng ban giới hạn thì phải chọn phòng ban trong phạm vi")
    void reports_requireModulePermissionAndScope() {
        var c = fixture.standardCompany();
        long kt = c.departments.get("KT");
        long sx = c.departments.get("SX");
        long roleId = api.post(c.adminToken, "/api/v1/roles", Map.of(
            "name", "Báo cáo KT", "description", "test",
            "permissions", List.of("REPORT_VIEW", "PAYROLL_VIEW"), "roleViewAllCompany", true,
            "deptScopes", Map.of("PAYROLL_VIEW", List.of(kt)))).expectOk().id();
        var u = c.emp(4);
        api.put(c.adminToken, "/api/v1/users/" + u.userId() + "/roles", Map.of("roleIds", List.of(roleId))).expectOk();
        String token = c.tokenOf(u);

        assertThat(api.get(token, "/api/v1/reports/payroll-summary?year=2026&month=9").status())
            .as("thiếu phòng ban").isEqualTo(400);
        assertThat(api.get(token, "/api/v1/reports/payroll-summary?year=2026&month=9&deptId=" + sx).status())
            .as("ngoài phạm vi").isEqualTo(403);
        assertThat(api.get(token, "/api/v1/reports/payroll-summary?year=2026&month=9&deptId=" + kt).status())
            .isEqualTo(200);
        assertThat(api.get(token, "/api/v1/reports/attendance-summary?year=2026&month=9").status())
            .as("không có ATTENDANCE_VIEW").isEqualTo(403);
        assertThat(api.get(c.adminToken, "/api/v1/reports/payroll-summary?year=2026&month=9").status())
            .as("admin toàn công ty").isEqualTo(200);
    }

}
