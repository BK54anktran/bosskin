package com.bosskin.it;

import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** Hồi quy cho phân quyền sửa ở Mốc 1 (D1, S6, A1, S7). */
class PermissionTest extends IntegrationTest {

    private static final LocalDate DAY = LocalDate.of(2026, 11, 3);

    @Test
    @DisplayName("S6 · Không cấp cho người khác vai trò có quyền mình không có")
    void s6_cannotGrantRoleWithPermissionsCallerLacks() {
        var c = fixture.standardCompany();
        c.createRole("Quản lý tài khoản", List.of("USER_MANAGE"));
        var manager = c.emp(4);
        c.setRole(manager, "Quản lý tài khoản");

        var res = api.put(c.tokenOf(manager), "/api/v1/users/" + c.emp(6).userId() + "/roles",
            Map.of("roleIds", List.of(c.roles.get("Kế toán"))));

        assertThat(res.status()).isEqualTo(403);
    }

    @Test
    @DisplayName("S6 · Không tạo vai trò có quyền vượt quyền của mình")
    void s6_cannotCreateRoleBeyondOwnPermissions() {
        var c = fixture.standardCompany();
        c.createRole("Quản lý vai trò", List.of("ROLE_MANAGE"));
        var e = c.emp(4);
        c.setRole(e, "Quản lý vai trò");

        var res = api.post(c.tokenOf(e), "/api/v1/roles", Map.of(
            "name", "Siêu quyền", "permissions", List.of("PAYROLL_VIEW", "PAYROLL_PAY")));

        assertThat(res.status()).isEqualTo(403);
    }

    @Test
    @DisplayName("A1 · Người duyệt công duyệt được công người khác nhưng không duyệt công của mình")
    void a1_approverCanApproveOthersButNotSelf() {
        var c = fixture.standardCompany();
        var approver = c.emp(1); // "Quản lý chấm công"
        long ownSa = c.assign(approver, "HC", DAY);
        long otherSa = c.assign(c.emp(6), "HC", DAY);
        String token = c.tokenOf(approver);

        var own = api.post(token, "/api/v1/attendances/approve", Map.of(
            "employeeId", approver.id(), "date", DAY.toString(), "shiftAssignmentId", ownSa));
        var other = api.post(token, "/api/v1/attendances/approve", Map.of(
            "employeeId", c.emp(6).id(), "date", DAY.toString(), "shiftAssignmentId", otherSa));

        assertThat(own.status()).isEqualTo(403);
        assertThat(other.status()).as(other.raw()).isEqualTo(200);
    }

    @Test
    @DisplayName("A2 · Phân ca của nhân viên khác cùng công ty cũng không gắn nhầm được")
    void a2_shiftAssignmentOfAnotherEmployee_isRejected() {
        var c = fixture.standardCompany();
        long saOfOther = c.assign(c.emp(7), "HC", DAY);

        var res = api.post(c.adminToken, "/api/v1/attendances/approve", Map.of(
            "employeeId", c.emp(6).id(), "date", DAY.toString(), "shiftAssignmentId", saOfOther));

        assertThat(res.status()).isEqualTo(404);
    }

    @Test
    @DisplayName("D1 · Vai trò mặc định chỉ xem được chấm công của chính mình")
    void d1_defaultRole_seesOnlyOwnAttendance() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.assign(e, "HC", DAY);
        c.assign(c.emp(7), "HC", DAY);
        api.post(c.adminToken, "/api/v1/attendances/approve", Map.of("employeeId", c.emp(7).id(), "date", DAY.toString())).expectOk();

        var res = api.get(c.tokenOf(e), "/api/v1/attendances?year=" + DAY.getYear() + "&month=" + DAY.getMonthValue()).expectOk();

        assertThat(res.raw()).doesNotContain(c.emp(7).code());
    }

    @Test
    @DisplayName("S7 · Người có quyền xem lương vẫn thấy số liệu lương trên dashboard")
    void s7_payrollViewerStillSeesSalary() {
        var c = fixture.standardCompany();
        var accountant = c.emp(2); // "Kế toán"

        var res = api.get(c.tokenOf(accountant), "/api/v1/dashboard/analytics?year=2026").expectOk();

        assertThat(res.body().has("salaryTrend")).isTrue();
    }

    @Test
    @DisplayName("S8 · Excel tổng hợp: có quyền xuất Excel nhưng không có quyền lương thì không xuất được bảng lương")
    void s8_excelExportRequiresModulePermission() {
        var c = fixture.standardCompany();
        c.createRole("Xuất Excel NV", List.of("EXCEL_EXPORT", "EMPLOYEE_VIEW"));
        var e = c.emp(4);
        c.setRole(e, "Xuất Excel NV");
        String token = c.tokenOf(e);

        var payroll = api.post(token, "/api/v1/excel/export", Map.of("types", List.of("payroll")));
        var employee = api.post(token, "/api/v1/excel/export", Map.of("types", List.of("employee")));

        assertThat(payroll.status()).isEqualTo(403);
        assertThat(employee.status()).as(employee.raw()).isEqualTo(200);
    }

    @Test
    @DisplayName("Nhiều vai trò cộng dồn theo hướng rộng nhất: Nhân viên (chỉ bản thân) + Quản lý (toàn công ty) duyệt được đơn người khác")
    void multipleRoles_broadestScopeWins() {
        var c = fixture.standardCompany();
        var manager = c.emp(1);
        var worker = c.emp(6);
        api.put(c.adminToken, "/api/v1/users/" + manager.userId() + "/roles",
            Map.of("roleIds", List.of(c.roles.get("Nhân viên"), c.roles.get("Quản lý chấm công")))).expectOk();
        c.grantLeaveDays(worker, "PN", 5);
        long id = api.post(c.tokenOf(worker), "/api/v1/leaves/requests", Map.of(
            "leaveTypeId", c.leaveTypes.get("PN"), "mode", "DAY_RANGE",
            "fromDate", "2026-11-20", "toDate", "2026-11-20", "reason", "Việc riêng")).expectOk().id();

        var res = api.put(c.tokenOf(manager), "/api/v1/leaves/requests/" + id + "/approve", Map.of());

        assertThat(res.status()).as(res.raw()).isEqualTo(200);
        var list = api.get(c.tokenOf(manager), "/api/v1/leaves/requests/page").expectOk().body();
        assertThat(list.path("totalElements").asInt()).as("thấy cả đơn của người khác").isGreaterThanOrEqualTo(1);
    }
}
