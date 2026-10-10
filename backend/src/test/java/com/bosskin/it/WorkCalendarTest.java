package com.bosskin.it;

import com.bosskin.entity.Payroll;
import com.bosskin.entity.SalaryFormula;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.ShiftAssignmentRepository;
import com.bosskin.service.PayrollService;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Bước J: ngày lễ (mẫu hệ thống + công ty chỉnh) và lịch làm việc tuần theo phòng ban.
 * Tháng 11/2026: 21 ngày T2–T6, 4 ngày T7 (7, 14, 21, 28); 24/11 là thứ Ba, nghỉ lễ có lương (mẫu V14).
 */
class WorkCalendarTest extends IntegrationTest {

    @Autowired PayrollService payrollService;
    @Autowired EmployeeRepository employeeRepository;
    @Autowired CompanyRepository companyRepository;
    @Autowired ShiftAssignmentRepository assignRepo;

    private static final LocalDate NOV_24 = LocalDate.of(2026, 11, 24);

    private void setContractSalary(Fixture.Emp e, long amount) {
        var emp = employeeRepository.findById(e.id()).orElseThrow();
        emp.setContractSalary(BigDecimal.valueOf(amount));
        employeeRepository.save(emp);
    }

    private void calendarMode(Fixture.TestCompany c) {
        var company = companyRepository.findById(c.id).orElseThrow();
        company.setStandardDaysFromCalendar(true);
        companyRepository.save(company);
    }

    private Payroll pay(Fixture.Emp e, String gross) {
        return payrollService.generatePayrollWithFormula(e.id(), 2026, 11, SalaryFormula.builder()
            .name("Test").expressionGross(gross).expressionNet("GROSS").build());
    }

    @Test
    @DisplayName("Kỳ 11/2026 theo mẫu: 24/11 là ngày lễ có lương — HOLIDAY_DAYS = 1, công chuẩn theo lịch = 21")
    void novemberPeriod_holidayFromTemplate() {
        var c = fixture.standardCompany();
        calendarMode(c);
        var e = c.emp(6);
        Payroll p = pay(e, "HOLIDAY_DAYS * 1000 + STANDARD_WORK_DAYS");
        assertThat(p.getGrossSalary()).isEqualByComparingTo("1021");
        assertThat(p.getStandardWorkDays()).isEqualByComparingTo("21");
    }

    @Test
    @DisplayName("Chế độ cố định vẫn dùng số 22 như cũ; HOLIDAY_DAYS vẫn có giá trị")
    void fixedMode_keepsStandardWorkDays() {
        var c = fixture.standardCompany();
        Payroll p = pay(c.emp(6), "HOLIDAY_DAYS * 1000 + STANDARD_WORK_DAYS");
        assertThat(p.getGrossSalary()).isEqualByComparingTo("1022");
        assertThat(p.getStandardWorkDays()).isEqualByComparingTo("22");
    }

    @Test
    @DisplayName("Phòng Sản xuất làm sáng T7 (FFFFFHO): công chuẩn 21 + 4 × 0,5 = 23; phòng khác vẫn 21")
    void saturdayHalfDay_department() {
        var c = fixture.standardCompany();
        calendarMode(c);
        long sx = c.departments.get("SX");
        api.post(c.adminToken, "/api/v1/work-calendars", Map.of(
            "name", "Xưởng — sáng T7", "weekPattern", "FFFFFHO", "departmentIds", List.of(sx))).expectOk();
        var worker = c.emp(6);   // SX
        var accountant = c.emp(3); // KT
        assertThat(pay(worker, "STANDARD_WORK_DAYS").getGrossSalary()).isEqualByComparingTo("23");
        assertThat(pay(accountant, "STANDARD_WORK_DAYS").getGrossSalary()).isEqualByComparingTo("21");

        // Bảng công: T7 của phòng SX là ngày làm, CN là ngày nghỉ, 24/11 nghỉ lễ có tên
        JsonNode rows = api.get(c.adminToken, "/api/v1/attendances/timesheet?employeeId=" + worker.id() + "&year=2026&month=11")
            .expectOk().body();
        for (JsonNode r : rows) {
            switch (r.path("date").asText()) {
                case "2026-11-07" -> assertThat(r.path("weekend").asBoolean()).isFalse();
                case "2026-11-08" -> assertThat(r.path("weekend").asBoolean()).isTrue();
                case "2026-11-24" -> {
                    assertThat(r.path("weekend").asBoolean()).isTrue();
                    assertThat(r.path("holidayName").asText()).isEqualTo("Ngày Văn hoá Việt Nam");
                }
                default -> { }
            }
        }
    }

    @Test
    @DisplayName("Làm ngày 24/11 ra HOLIDAY_OT_HOURS = 8 giờ")
    void workOnHoliday_countsHolidayHours() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        long sa = c.assign(e, "HC", NOV_24);
        String token = c.tokenOf(e);
        clock.set(NOV_24.atTime(7, 55));
        api.post(token, "/api/v1/attendances/self/check-in", Map.of()).expectOk();
        clock.set(NOV_24.atTime(17, 2));
        api.post(token, "/api/v1/attendances/self/check-out", Map.of()).expectOk();
        api.post(c.adminToken, "/api/v1/attendances/approve", Map.of(
            "employeeId", e.id(), "date", NOV_24.toString(), "shiftAssignmentId", sa)).expectOk();
        assertThat(pay(e, "HOLIDAY_OT_HOURS").getGrossSalary()).isEqualByComparingTo("8");
    }

    @Test
    @DisplayName("Đơn nghỉ 23–25/11 chỉ trừ 2 ngày; xin nghỉ đúng 24/11 bị từ chối")
    void leaveSkipsHoliday() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.grantLeaveDays(e, "PN", 5);
        String token = c.tokenOf(e);
        var res = api.post(token, "/api/v1/leaves/requests", Map.of(
            "leaveTypeId", c.leaveTypes.get("PN"), "mode", "DAY_RANGE",
            "fromDate", "2026-11-23", "toDate", "2026-11-25", "reason", "Về quê")).expectOk().body();
        assertThat(res.path("requestedAmount").decimalValue()).isEqualByComparingTo("2");
        var other = c.emp(7);
        c.grantLeaveDays(other, "PN", 5);
        var single = api.post(c.tokenOf(other), "/api/v1/leaves/requests", Map.of(
            "leaveTypeId", c.leaveTypes.get("PN"), "mode", "DAY_RANGE",
            "fromDate", "2026-11-24", "toDate", "2026-11-24", "reason", "Lễ"));
        assertThat(single.status()).isEqualTo(400);
        assertThat(single.raw()).contains("error.leave.holiday");
    }

    @Test
    @DisplayName("Công ty sửa ngày lễ mẫu: chép mẫu năm đó sang công ty, công ty khác vẫn theo mẫu; trùng ngày 409; NV không có quyền 403")
    void companyCopyOnWrite() {
        var c = fixture.standardCompany();
        var other = fixture.newCompany();
        JsonNode y = api.get(c.adminToken, "/api/v1/holidays?year=2026").expectOk().body();
        assertThat(y.path("customized").asBoolean()).isFalse();
        assertThat(y.path("items").size()).isEqualTo(12);
        long templateId = -1;
        for (JsonNode h : y.path("items")) if (h.path("date").asText().equals("2026-09-01")) templateId = h.path("id").asLong();

        api.put(c.adminToken, "/api/v1/holidays/" + templateId, Map.of(
            "date", "2026-09-03", "name", "Quốc khánh (ngày liền kề)", "type", "HOLIDAY", "paid", true)).expectOk();
        JsonNode after = api.get(c.adminToken, "/api/v1/holidays?year=2026").expectOk().body();
        assertThat(after.path("customized").asBoolean()).isTrue();
        List<String> dates = new ArrayList<>();
        for (JsonNode h : after.path("items")) {
            dates.add(h.path("date").asText());
            assertThat(h.path("source").asText()).isEqualTo("COMPANY");
        }
        assertThat(dates).contains("2026-09-03").doesNotContain("2026-09-01").hasSize(12);

        JsonNode otherYear = api.get(other.adminToken, "/api/v1/holidays?year=2026").expectOk().body();
        assertThat(otherYear.path("customized").asBoolean()).isFalse();

        var dup = api.post(c.adminToken, "/api/v1/holidays", Map.of(
            "date", "2026-11-24", "name", "Trùng", "type", "HOLIDAY", "paid", true));
        assertThat(dup.status()).isEqualTo(409);

        // Nghỉ bù thứ Hai 7/12 + xoá 24/11: kỳ 12/2026 có thêm 1 ngày lễ
        api.post(c.adminToken, "/api/v1/holidays", Map.of(
            "date", "2026-12-07", "name", "Nghỉ bù", "type", "COMPENSATORY", "paid", true)).expectOk();
        long nov24 = -1;
        for (JsonNode h : after.path("items")) if (h.path("date").asText().equals("2026-11-24")) nov24 = h.path("id").asLong();
        api.delete(c.adminToken, "/api/v1/holidays/" + nov24).expectOk();
        assertThat(pay(c.emp(6), "HOLIDAY_DAYS").getGrossSalary()).isEqualByComparingTo("0");
        assertThat(payrollService.generatePayrollWithFormula(c.emp(6).id(), 2026, 12, SalaryFormula.builder()
            .name("T").expressionGross("HOLIDAY_DAYS").expressionNet("GROSS").build()).getGrossSalary())
            .isEqualByComparingTo("1");

        String employee = c.tokenOf(c.emp(6));
        assertThat(api.get(employee, "/api/v1/holidays?year=2026").status()).isEqualTo(403);
        assertThat(api.post(employee, "/api/v1/work-calendars", Map.of("name", "X", "weekPattern", "FFFFFFF")).status())
            .isEqualTo(403);
    }

    @Test
    @DisplayName("Ngày làm bù T7 + nghỉ hoán đổi T2 (không lương): công chuẩn không đổi, HOLIDAY_DAYS không tăng")
    void swapWorkday_keepsStandardDays() {
        var c = fixture.standardCompany();
        calendarMode(c);
        api.post(c.adminToken, "/api/v1/holidays", Map.of(
            "date", "2026-11-14", "name", "Làm bù", "type", "SWAP_WORKDAY", "paid", true)).expectOk();
        api.post(c.adminToken, "/api/v1/holidays", Map.of(
            "date", "2026-11-23", "name", "Nghỉ hoán đổi", "type", "HOLIDAY", "paid", false)).expectOk();
        Payroll p = pay(c.emp(6), "HOLIDAY_DAYS * 1000 + STANDARD_WORK_DAYS");
        assertThat(p.getGrossSalary()).isEqualByComparingTo("1021");
    }

    @Test
    @DisplayName("Nhập lịch Tết 2027 qua xem trước: preview báo CREATE/UPDATE/DELETE, import xong năm 2027 thành của công ty")
    void importTet2027_withPreview() throws Exception {
        var c = fixture.standardCompany();
        byte[] file = xlsx(List.of(
            new String[]{"2027-02-10", "Tết Âm lịch (Mùng 5)", "HOLIDAY", "1", ""},
            new String[]{"2027-02-05", "Tết Âm lịch (29 Tết)", "HOLIDAY", "1", ""},
            new String[]{"2027-09-03", "", "", "", "x"},
            new String[]{"2027-02-20", "Làm bù Tết", "SWAP_WORKDAY", "1", ""}));
        JsonNode diffs = api.upload(c.adminToken, "/api/v1/holidays/preview-import", "tet-2027.xlsx", file).expectOk().body();
        Map<String, String> actions = new java.util.HashMap<>();
        for (JsonNode d : diffs) actions.put(d.path("code").asText(), d.path("action").asText());
        assertThat(actions).containsEntry("2027-02-10", "CREATE").containsEntry("2027-02-05", "UPDATE")
            .containsEntry("2027-09-03", "DELETE").containsEntry("2027-02-20", "CREATE");
        // Xem trước không ghi gì
        assertThat(api.get(c.adminToken, "/api/v1/holidays?year=2027").expectOk().body().path("customized").asBoolean()).isFalse();

        JsonNode result = api.upload(c.adminToken, "/api/v1/holidays/import", "tet-2027.xlsx", file).expectOk().body();
        assertThat(result.path("created").asInt()).isEqualTo(2);
        assertThat(result.path("updated").asInt()).isEqualTo(1);
        assertThat(result.path("deleted").asInt()).isEqualTo(1);
        JsonNode y = api.get(c.adminToken, "/api/v1/holidays?year=2027").expectOk().body();
        assertThat(y.path("customized").asBoolean()).isTrue();
        assertThat(y.path("items").size()).isEqualTo(13); // 12 mẫu + 2 mới − 1 xoá

        // Xuất lại đọc được bằng đúng định dạng nhập
        assertThat(api.get(c.adminToken, "/api/v1/holidays/export?year=2027").status()).isEqualTo(200);
    }

    @Test
    @DisplayName("Xoay ca bỏ qua ngày lễ: 24/11 để trống ca, ngày khác theo mẫu")
    void rotationSkipsHolidays() {
        var c = fixture.standardCompany();
        long hc = c.shifts.get("HC");
        long rotId = api.post(c.adminToken, "/api/v1/shift-rotations", Map.of(
            "name", "HC mỗi ngày", "days", List.of(List.of(hc)))).expectOk().id();
        var e = c.emp(6);
        api.post(c.adminToken, "/api/v1/shift-rotations/" + rotId + "/generate", Map.of(
            "employeeIds", List.of(e.id()), "from", "2026-11-23", "to", "2026-11-25",
            "startOffset", 0, "staggerPerEmployee", 0, "skipHolidays", true)).expectOk();
        assertThat(assignRepo.findByEmployeeIdAndWorkDate(e.id(), LocalDate.of(2026, 11, 23))).hasSize(1);
        assertThat(assignRepo.findByEmployeeIdAndWorkDate(e.id(), NOV_24)).isEmpty();
        assertThat(assignRepo.findByEmployeeIdAndWorkDate(e.id(), LocalDate.of(2026, 11, 25))).hasSize(1);
    }

    @Test
    @DisplayName("Lịch xem cho lưới phân ca: phòng con kế thừa lịch phòng cha; lịch mặc định đổi được")
    void viewInheritsParentCalendar() {
        var c = fixture.standardCompany();
        long sx = c.departments.get("SX");
        long child = c.createDepartment("SX1", "Tổ 1", sx);
        api.post(c.adminToken, "/api/v1/work-calendars", Map.of(
            "name", "Xưởng", "weekPattern", "FFFFFFO", "departmentIds", List.of(sx))).expectOk();
        api.put(c.adminToken, "/api/v1/work-calendars/default", Map.of("weekPattern", "FFFFFHO")).expectOk();
        JsonNode v = api.get(c.tokenOf(c.emp(1)), "/api/v1/work-calendars/view?from=2026-11-01&to=2026-11-30")
            .expectOk().body();
        assertThat(v.path("defaultPattern").asText()).isEqualTo("FFFFFHO");
        assertThat(v.path("departmentPatterns").path(String.valueOf(child)).asText()).isEqualTo("FFFFFFO");
        assertThat(v.path("departmentPatterns").path(String.valueOf(c.departments.get("KT"))).asText()).isEqualTo("FFFFFHO");
        assertThat(v.path("holidays").size()).isEqualTo(1);
        assertThat(api.put(c.adminToken, "/api/v1/work-calendars/default", Map.of("weekPattern", "XYZ")).status())
            .isEqualTo(400);

        // Danh sách lịch: mặc định trước (isDefault), lịch Xưởng gán SX; ô chọn phòng ban có cả phòng con
        JsonNode cals = api.get(c.adminToken, "/api/v1/work-calendars").expectOk().body();
        assertThat(cals.get(0).path("isDefault").asBoolean()).isTrue();
        assertThat(cals.get(1).path("departmentIds").get(0).asLong()).isEqualTo(sx);
        JsonNode depts = api.get(c.adminToken, "/api/v1/work-calendars/departments").expectOk().body();
        assertThat(depts.findValuesAsText("name")).contains("Tổ 1");
        assertThat(api.get(c.tokenOf(c.emp(1)), "/api/v1/work-calendars/departments").status()).isEqualTo(403);
    }

    @Test
    @DisplayName("System admin sửa mẫu ngày lễ; user công ty không gọi được")
    void templateAdmin() {
        String sys = api.post(null, "/admin/auth/login", Map.of("email", "sysadmin@test.local", "password", "Test-SysAdmin-123"))
            .expectOk().text("accessToken");
        assertThat(api.get(sys, "/admin/holidays/years").expectOk().body().toString()).contains("2026", "2027");
        long id = api.post(sys, "/admin/holidays", Map.of(
            "date", "2099-01-01", "name", "Thử", "type", "HOLIDAY", "paid", true)).expectOk().id();
        try {
            assertThat(api.get(sys, "/admin/holidays?year=2099").expectOk().body().size()).isEqualTo(1);
            assertThat(api.put(sys, "/admin/holidays/" + id, Map.of(
                "date", "2099-01-02", "name", "Thử 2", "type", "HOLIDAY", "paid", false)).expectOk()
                .body().path("paid").asBoolean()).isFalse();
            var c = fixture.newCompany();
            assertThat(api.get(c.adminToken, "/admin/holidays?year=2099").status()).isIn(401, 403);
        } finally {
            api.delete(sys, "/admin/holidays/" + id).expectOk();
        }
    }

    private static byte[] xlsx(List<String[]> rows) throws Exception {
        try (XSSFWorkbook wb = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            var sheet = wb.createSheet("Ngày lễ");
            String[] header = {"Ngày (yyyy-mm-dd) (*)", "Tên ngày lễ (*)", "Loại (HOLIDAY/COMPENSATORY/SWAP_WORKDAY)",
                "Có lương (1/0)", "Xóa (x)"};
            var h = sheet.createRow(0);
            for (int i = 0; i < header.length; i++) h.createCell(i).setCellValue(header[i]);
            for (int r = 0; r < rows.size(); r++) {
                var row = sheet.createRow(r + 1);
                for (int i = 0; i < rows.get(r).length; i++) row.createCell(i).setCellValue(rows.get(r)[i]);
            }
            wb.write(out);
            return out.toByteArray();
        }
    }
}
