package com.bosskin.it;

import com.bosskin.support.IntegrationTest;
import com.bosskin.util.ExcelI18n;
import com.fasterxml.jackson.databind.JsonNode;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.assertj.core.api.Assertions.assertThat;

/** Các mục còn mở trong trang Đánh giá, dọn ngày 10/10/2026 (D6, D8, D9, D10, D11, D12, A20). */
class DataIntegrityTest extends IntegrationTest {

    @Autowired ExcelI18n excelI18n;
    @Autowired JdbcTemplate jdbc;

    private static final Locale VI = Locale.forLanguageTag("vi");

    // ── D6 ──────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("D6 · Mã NV không trùng sau khi xoá nhân viên và khi tạo đồng thời")
    void employeeCode_neverReused() throws Exception {
        var c = fixture.newCompany();
        c.createDepartment("PB", "Phòng B", null);
        var a = c.createEmployee("Nguyễn A", "PB");
        var b = c.createEmployee("Nguyễn B", "PB");
        assertThat(a.code()).isEqualTo(c.code + "00001");
        assertThat(b.code()).isEqualTo(c.code + "00002");

        // Xoá A rồi tạo người mới: count + 1 trước đây ra lại mã 00002 (trùng B)
        api.delete(c.adminToken, "/api/v1/employees/" + a.id()).expectOk();
        var d = c.createEmployee("Nguyễn D", "PB");
        assertThat(d.code()).isEqualTo(c.code + "00003");

        // 6 yêu cầu tạo cùng lúc → 6 mã khác nhau
        List<Callable<String>> jobs = new ArrayList<>();
        for (int i = 0; i < 6; i++) {
            int n = i;
            jobs.add(() -> {
                Map<String, Object> body = new LinkedHashMap<>();
                body.put("fullName", "Song song " + n);
                body.put("email", "ss" + n + "@" + c.code.toLowerCase() + ".test");
                body.put("password", "Test@12345");
                body.put("gender", "MALE");
                body.put("joinDate", "2025-01-01");
                body.put("departmentId", c.departments.get("PB"));
                return api.post(c.adminToken, "/api/v1/employees", body).expectOk().text("employeeCode");
            });
        }
        var pool = Executors.newFixedThreadPool(6);
        List<String> codes = new ArrayList<>();
        for (Future<String> f : pool.invokeAll(jobs)) codes.add(f.get());
        pool.shutdown();
        assertThat(codes).doesNotHaveDuplicates().allMatch(s -> s.matches(c.code + "\\d{5}"));
        assertThat(codes).doesNotContain(c.code + "00001", c.code + "00002", c.code + "00003");
    }

    // ── D8 ──────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("D8 · Không chọn phòng con làm cha; đổi cha tính lại cấp cho cả nhánh")
    void departmentTree_rejectsCycleAndRecomputesLevels() {
        var c = fixture.newCompany();
        long a = c.createDepartment("A", "A", null);
        long b = c.createDepartment("B", "B", a);
        long cc = c.createDepartment("C", "C", b);
        long x = c.createDepartment("X", "X", null);

        var cycle = api.put(c.adminToken, "/api/v1/departments/" + a, Map.of("code", "A", "name", "A", "parentId", cc));
        assertThat(cycle.status()).isEqualTo(400);
        assertThat(cycle.raw()).contains("error.department.parent_cycle");

        // Chuyển A xuống dưới X → A cấp 1, B cấp 2, C cấp 3
        api.put(c.adminToken, "/api/v1/departments/" + a, Map.of("code", "A", "name", "A", "parentId", x)).expectOk();
        Map<String, Integer> levels = levels(c.adminToken);
        assertThat(levels).containsEntry("X", 0).containsEntry("A", 1).containsEntry("B", 2).containsEntry("C", 3);
    }

    @Test
    @DisplayName("D8 · Import phòng ban: dòng con đứng trước cha vẫn được; chặn vòng lặp; không xoá phòng còn NV")
    void departmentImport_orderIndependent_cycleAndEmployeesGuarded() throws Exception {
        var c = fixture.newCompany();
        c.createDepartment("CO", "Có người", null);
        c.createEmployee("Nhân viên", "CO");

        // Con (CON) đứng trước cha (CHA) trong file
        byte[] ok = deptFile(List.of(
            new String[]{"CON", "Phòng con", "CHA", ""},
            new String[]{"CHA", "Phòng cha", "", ""}));
        api.upload(c.adminToken, "/api/v1/departments/import", "pb.xlsx", ok).expectOk();
        assertThat(levels(c.adminToken)).containsEntry("CHA", 0).containsEntry("CON", 1);

        byte[] loop = deptFile(List.of(
            new String[]{"CHA", "Phòng cha", "CON", ""},
            new String[]{"CON", "Phòng con", "CHA", ""}));
        var r = api.upload(c.adminToken, "/api/v1/departments/import", "pb.xlsx", loop);
        assertThat(r.status()).isEqualTo(400);
        assertThat(r.raw()).contains("error.import.department_cycle");
        assertThat(levels(c.adminToken)).containsEntry("CHA", 0).containsEntry("CON", 1); // không đổi gì

        byte[] del = deptFile(List.<String[]>of(new String[]{"CO", "Có người", "", "x"}));
        var d = api.upload(c.adminToken, "/api/v1/departments/import", "pb.xlsx", del);
        assertThat(d.status()).isEqualTo(409);
        assertThat(d.raw()).contains("error.import.department_has_employees|CO|1");
    }

    // ── D9 ──────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("D9 · Excel: SĐT / CCCD gõ dạng số giữ số 0 đầu; tài khoản import không dùng chung mật khẩu cố định")
    void employeeImport_keepsLeadingZeros_randomPassword() throws Exception {
        var c = fixture.newCompany();
        c.createDepartment("PB", "Phòng B", null);
        String email = "nhap@" + c.code.toLowerCase() + ".test";

        byte[] file;
        try (XSSFWorkbook wb = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Sheet s1 = wb.createSheet("1");
            header(s1, "excel.col.employee.code", "excel.col.employee.fullName", "excel.col.employee.email",
                "excel.col.employee.phone", "excel.col.employee.gender", "excel.col.employee.joinDate",
                "excel.col.employee.departmentCode");
            Row r = s1.createRow(1);
            r.createCell(0).setCellValue(c.code + "900");
            r.createCell(1).setCellValue("Trần Nhập");
            r.createCell(2).setCellValue(email);
            r.createCell(3).setCellValue(912345678d);          // gõ 0912345678 nhưng Excel lưu số
            r.createCell(4).setCellValue("Nữ");
            r.createCell(5).setCellValue("01/03/2026");
            r.createCell(6).setCellValue("PB");
            Sheet s2 = wb.createSheet("2");
            header(s2, "excel.col.employee.code", "excel.col.employee.fullName", "excel.col.employee.identityCard");
            Row p = s2.createRow(1);
            p.createCell(0).setCellValue(c.code + "900");
            p.createCell(1).setCellValue("Trần Nhập");
            p.createCell(2).setCellValue(1203004567d);         // CCCD 001203004567 bị Excel lưu thành số
            wb.write(out);
            file = out.toByteArray();
        }
        api.upload(c.adminToken, "/api/v1/employees/import", "nv.xlsx", file).expectOk();

        JsonNode list = api.get(c.adminToken, "/api/v1/employees?size=50").expectOk().body();
        JsonNode emp = null;
        for (JsonNode e : list.path("content")) if (email.equals(e.path("email").asText())) emp = e;
        assertThat(emp).isNotNull();
        assertThat(emp.path("phone").asText()).isEqualTo("0912345678");
        assertThat(api.get(c.adminToken, "/api/v1/employees/" + emp.path("id").asLong()).expectOk().text("identityCard"))
            .endsWith("4567");
        assertThat(jdbc.queryForObject("SELECT identity_card FROM employees WHERE id = ?", String.class, emp.path("id").asLong()))
            .isEqualTo("001203004567");

        // Mật khẩu cố định cũ không còn đăng nhập được
        assertThat(api.login(email, "Bosskin@123").status()).isNotEqualTo(200);

        // Quản trị xuất mật khẩu tạm → đăng nhập được, phải đổi mật khẩu
        byte[] xlsx = api.downloadPost(c.adminToken, "/api/v1/users/initial-passwords");
        String pw = null;
        try (XSSFWorkbook wb = new XSSFWorkbook(new ByteArrayInputStream(xlsx))) {
            Sheet sh = wb.getSheetAt(0);
            for (int i = 1; i <= sh.getLastRowNum(); i++) {
                if (email.equals(sh.getRow(i).getCell(3).getStringCellValue())) pw = sh.getRow(i).getCell(4).getStringCellValue();
            }
        }
        assertThat(pw).isNotBlank();
        var login = api.login(email, pw);
        assertThat(login.status()).isEqualTo(200);
        assertThat(login.body().path("user").path("mustChangePassword").asBoolean()).isTrue();
    }

    @Test
    @DisplayName("D9 · Đọc ô số định dạng 000… và chuẩn hoá CCCD / SĐT")
    void excelText_normalization() {
        assertThat(com.bosskin.util.ExcelText.phone("912345678")).isEqualTo("0912345678");
        assertThat(com.bosskin.util.ExcelText.phone("0912345678")).isEqualTo("0912345678");
        assertThat(com.bosskin.util.ExcelText.phone("+84912345678")).isEqualTo("+84912345678");
        assertThat(com.bosskin.util.ExcelText.identityCard("1203004567")).isEqualTo("001203004567");
        assertThat(com.bosskin.util.ExcelText.identityCard("079203004567")).isEqualTo("079203004567");
        assertThat(com.bosskin.util.ExcelText.identityCard("01203004567")).isEqualTo("001203004567");
        assertThat(com.bosskin.util.ExcelText.identityCard("12345678")).isEqualTo("012345678");
        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            var cell = wb.createSheet().createRow(0).createCell(0);
            var st = wb.createCellStyle();
            st.setDataFormat(wb.createDataFormat().getFormat("000000000000"));
            cell.setCellStyle(st);
            cell.setCellValue(1203004567d);
            assertThat(com.bosskin.util.ExcelText.numeric(cell)).isEqualTo("001203004567");
        } catch (java.io.IOException e) {
            throw new RuntimeException(e);
        }
    }

    @Test
    @DisplayName("D9 · Đặt lại mật khẩu NV: chỉ trong phạm vi, không tự đặt lại cho mình, mật khẩu cũ hết hiệu lực")
    void resetPassword() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        var res = api.post(c.adminToken, "/api/v1/users/" + e.userId() + "/reset-password", null).expectOk();
        String pw = res.text("password");
        assertThat(pw).hasSizeGreaterThanOrEqualTo(10);
        assertThat(api.login(e.email(), com.bosskin.support.Fixture.PASSWORD).status()).isNotEqualTo(200);
        assertThat(api.login(e.email(), pw).body().path("user").path("mustChangePassword").asBoolean()).isTrue();

        var adminUserId = jdbc.queryForObject("SELECT id FROM users WHERE email = ?", Long.class, c.adminEmail);
        var self = api.post(c.adminToken, "/api/v1/users/" + adminUserId + "/reset-password", null);
        assertThat(self.status()).isEqualTo(400);
        assertThat(self.raw()).contains("error.user.cannot_reset_self");

        // Nhân viên thường không có USER_MANAGE
        assertThat(api.post(c.tokenOf(c.emp(5)), "/api/v1/users/" + e.userId() + "/reset-password", null).status())
            .isEqualTo(403);
    }

    // ── D11 ─────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("D11 · Duyệt sửa hồ sơ theo phạm vi, không tự duyệt, lưu giá trị cũ")
    void profileEditRequest_scopeSelfAndOldValues() {
        var c = fixture.standardCompany();
        long kt = c.departments.get("KT");
        var ktEmp = c.employees.stream().filter(x -> x.departmentId() == kt).findFirst().orElseThrow();
        var sxEmp = c.employees.stream().filter(x -> x.departmentId() == c.departments.get("SX")).findFirst().orElseThrow();

        long roleId = api.post(c.adminToken, "/api/v1/roles", Map.of(
            "name", "HR phòng KT", "description", "test",
            "permissions", List.of("EMPLOYEE_VIEW", "EMPLOYEE_UPDATE"), "roleViewAllCompany", true,
            "deptScopes", Map.of("EMPLOYEE_UPDATE", List.of(kt)))).expectOk().id();
        api.put(c.adminToken, "/api/v1/users/" + ktEmp.userId() + "/roles", Map.of("roleIds", List.of(roleId))).expectOk();
        String hr = c.tokenOf(ktEmp);

        long fromSx = api.post(c.tokenOf(sxEmp), "/api/v1/profile/edit-requests", Map.of("phone", "0900000001")).expectOk().id();
        long own = api.post(hr, "/api/v1/profile/edit-requests", Map.of("phone", "0900000002")).expectOk().id();

        JsonNode visible = api.get(hr, "/api/v1/profile/edit-requests?status=PENDING").expectOk().body();
        List<Long> ids = new ArrayList<>();
        visible.forEach(n -> ids.add(n.path("id").asLong()));
        assertThat(ids).contains(own).doesNotContain(fromSx);

        assertThat(api.put(hr, "/api/v1/profile/edit-requests/" + fromSx + "/approve", null).status()).isEqualTo(403);
        var self = api.put(hr, "/api/v1/profile/edit-requests/" + own + "/approve", null);
        assertThat(self.status()).isEqualTo(403);
        assertThat(self.raw()).contains("error.profile.cannot_process_own");

        String oldPhone = api.get(c.adminToken, "/api/v1/employees/" + sxEmp.id()).expectOk().text("phone");
        var approved = api.put(c.adminToken, "/api/v1/profile/edit-requests/" + fromSx + "/approve", null).expectOk();
        assertThat(approved.text("requestedPhone")).isEqualTo("0900000001");
        assertThat(approved.body().path("currentPhone").isNull() ? null : approved.text("currentPhone")).isEqualTo(oldPhone);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM audit_logs WHERE action = 'PROFILE_EDIT_APPROVE' AND company_id = ?",
            Integer.class, c.id)).isEqualTo(1);
    }

    // ── A20 / D12 / D10 ─────────────────────────────────────────────────────

    @Test
    @DisplayName("A20 · Phân ca chỉ trả NV trong phạm vi SHIFT_VIEW của người xem")
    void shiftAssignments_respectScope() {
        var c = fixture.standardCompany();
        long kt = c.departments.get("KT");
        var ktEmp = c.employees.stream().filter(x -> x.departmentId() == kt).findFirst().orElseThrow();
        var sxEmp = c.employees.stream().filter(x -> x.departmentId() == c.departments.get("SX")).findFirst().orElseThrow();
        var day = java.time.LocalDate.of(2026, 11, 3);
        c.assign(ktEmp, "HC", day);
        c.assign(sxEmp, "HC", day);

        long roleId = api.post(c.adminToken, "/api/v1/roles", Map.of(
            "name", "Xem ca KT", "description", "test",
            "permissions", List.of("SHIFT_VIEW"), "roleViewAllCompany", true,
            "deptScopes", Map.of("SHIFT_VIEW", List.of(kt)))).expectOk().id();
        var viewer = c.emp(9);
        api.put(c.adminToken, "/api/v1/users/" + viewer.userId() + "/roles", Map.of("roleIds", List.of(roleId))).expectOk();
        String token = c.tokenOf(viewer);

        JsonNode list = api.get(token, "/api/v1/shifts/assignments?from=2026-11-01&to=2026-11-30").expectOk().body();
        List<Long> empIds = new ArrayList<>();
        list.forEach(n -> empIds.add(n.path("employeeId").asLong()));
        assertThat(empIds).contains(ktEmp.id()).doesNotContain(sxEmp.id());
        assertThat(api.get(token, "/api/v1/shifts/assignments/employee/" + sxEmp.id() + "?from=2026-11-01&to=2026-11-30").status())
            .isEqualTo(403);
    }

    @Test
    @DisplayName("D12 · Phạm vi phòng ban chỉ nhận phòng của chính công ty; D10 · danh sách người dùng vẫn đủ phạm vi")
    void deptScopes_validatedAndListed() {
        var c = fixture.standardCompany();
        var other = fixture.newCompany();
        long foreign = other.createDepartment("NGOAI", "Phòng công ty khác", null);
        var e = c.emp(6);

        var bad = api.put(c.adminToken, "/api/v1/users/" + e.userId() + "/dept-scopes", Map.of("EMPLOYEE_VIEW", List.of(foreign)));
        assertThat(bad.status()).isEqualTo(400);
        assertThat(bad.raw()).contains("error.role.scope_department_invalid");
        var badRole = api.post(c.adminToken, "/api/v1/roles", Map.of(
            "name", "Sai phạm vi", "description", "test", "permissions", List.of("EMPLOYEE_VIEW"), "roleViewAllCompany", true,
            "deptScopes", Map.of("EMPLOYEE_VIEW", List.of(foreign))));
        assertThat(badRole.status()).isEqualTo(400);

        long kt = c.departments.get("KT");
        api.put(c.adminToken, "/api/v1/users/" + e.userId() + "/permissions", Map.of("permissionCodes", List.of("EMPLOYEE_VIEW"))).expectOk();
        api.put(c.adminToken, "/api/v1/users/" + e.userId() + "/dept-scopes", Map.of("EMPLOYEE_VIEW", List.of(kt))).expectOk();
        JsonNode users = api.get(c.adminToken, "/api/v1/users").expectOk().body();
        JsonNode row = null;
        for (JsonNode u : users) if (u.path("id").asLong() == e.userId()) row = u;
        assertThat(row).isNotNull();
        assertThat(row.path("deptScopes").path("EMPLOYEE_VIEW").get(0).asLong()).isEqualTo(kt);
        assertThat(row.path("roles").size()).isGreaterThan(0);
    }

    // ── helpers ─────────────────────────────────────────────────────────────

    private Map<String, Integer> levels(String token) {
        Map<String, Integer> m = new LinkedHashMap<>();
        api.get(token, "/api/v1/departments/flat").expectOk().body()
            .forEach(n -> m.put(n.path("code").asText(), n.path("level").asInt()));
        return m;
    }

    private void header(Sheet sh, String... keys) {
        Row h = sh.createRow(0);
        for (int i = 0; i < keys.length; i++) h.createCell(i).setCellValue(excelI18n.resolve(keys[i], VI));
    }

    /** Cột: mã, tên, mã cha, xoá. */
    private byte[] deptFile(List<String[]> rows) throws Exception {
        try (XSSFWorkbook wb = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Sheet sh = wb.createSheet("PB");
            header(sh, "excel.col.department.code", "excel.col.department.name",
                "excel.col.department.parentCode", "excel.col.department.delete");
            int r = 1;
            for (String[] v : rows) {
                Row row = sh.createRow(r++);
                for (int i = 0; i < v.length; i++) row.createCell(i).setCellValue(v[i]);
            }
            wb.write(out);
            return out.toByteArray();
        }
    }
}
