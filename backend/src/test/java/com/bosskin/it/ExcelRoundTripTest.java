package com.bosskin.it;

import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.DataFormatter;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Xuất → (sửa) → xem trước → nhập lại cho mọi màn có Excel (13/10/2026). Quy tắc dự án: file xuất phải nhập lại được;
 * nhập lại nguyên file không đổi gì; sửa một ô thì xem trước báo đúng thay đổi và nhập vào thì áp dụng.
 */
class ExcelRoundTripTest extends IntegrationTest {

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired JdbcTemplate jdbc;

    static final LocalDate D1 = LocalDate.of(2026, 11, 2);
    static final DataFormatter FMT = new DataFormatter();

    // ── tiện ích Excel ───────────────────────────────────────────────────────

    interface WbChange { void apply(XSSFWorkbook wb) throws Exception; }

    static byte[] edit(byte[] file, WbChange change) throws Exception {
        try (XSSFWorkbook wb = new XSSFWorkbook(new ByteArrayInputStream(file))) {
            change.apply(wb);
            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            wb.write(bos);
            return bos.toByteArray();
        }
    }

    static int col(Sheet sh, int headerRow, String headerStartsWith) {
        Row h = sh.getRow(headerRow);
        for (Cell c : h) if (FMT.formatCellValue(c).trim().startsWith(headerStartsWith)) return c.getColumnIndex();
        throw new AssertionError("không có cột '" + headerStartsWith + "' trong sheet " + sh.getSheetName());
    }

    static Row rowWhere(Sheet sh, int keyCol, String key) {
        for (Row r : sh) if (r.getRowNum() > 0 && key.equals(FMT.formatCellValue(r.getCell(keyCol)).trim())) return r;
        throw new AssertionError("không có dòng '" + key + "' trong sheet " + sh.getSheetName());
    }

    static void set(Row r, int col, String v) {
        Cell c = r.getCell(col);
        if (c == null) c = r.createCell(col);
        c.setCellValue(v);
    }

    /** Mọi diff trong phản hồi xem trước (mảng, hoặc map sheet → mảng ở Excel chung). */
    static List<JsonNode> diffs(JsonNode body) {
        List<JsonNode> out = new ArrayList<>();
        if (body.isArray()) body.forEach(out::add);
        else if (body.has("diffs")) body.path("diffs").forEach(out::add);   // phân ca: {diffs, sectionLabels, sectionCounts}
        else body.fields().forEachRemaining(e -> e.getValue().forEach(out::add));
        return out;
    }

    static List<String> actions(JsonNode body) {
        return diffs(body).stream().map(d -> d.path("action").asText()).toList();
    }

    /** Không có dòng lỗi / cảnh báo nào. */
    static void noProblems(JsonNode body) {
        for (JsonNode d : diffs(body)) {
            assertThat(d.path("action").asText()).as(d.toString()).isNotIn("ERROR", "WARN");
            assertThat(d.path("warnings").isMissingNode() || d.path("warnings").isEmpty()).as(d.toString()).isTrue();
            assertThat(d.path("error").isMissingNode() || d.path("error").isNull()).as(d.toString()).isTrue();
        }
    }

    JsonNode preview(Fixture.TestCompany c, String url, byte[] file) {
        var r = api.upload(c.adminToken, url, "f.xlsx", file);
        assertThat(r.status()).as(url + " " + r.raw()).isEqualTo(200);
        return r.body();
    }

    void doImport(Fixture.TestCompany c, String url, byte[] file) {
        var r = api.upload(c.adminToken, url, "f.xlsx", file);
        assertThat(r.status()).as(url + " " + r.raw()).isBetween(200, 299);
    }

    /** Xuất → xem trước nhập lại nguyên file: không lỗi, không có dòng tạo / sửa / xoá. */
    byte[] exportAndCheckUnchanged(Fixture.TestCompany c, String exportUrl, String previewUrl) {
        byte[] file = api.download(c.adminToken, exportUrl);
        JsonNode prev = preview(c, previewUrl, file);
        diffs(prev).stream().filter(d -> !d.path("action").asText().equals("NO_CHANGE"))
            .forEach(d -> System.out.println("ODD " + previewUrl + " " + d));
        noProblems(prev);
        assertThat(actions(prev)).as(previewUrl + " nhập lại nguyên file").allMatch(a -> a.equals("NO_CHANGE"));
        return file;
    }

    String one(String sql, Object... args) {
        return jdbc.queryForObject(sql, String.class, args);
    }

    // ── test theo màn ────────────────────────────────────────────────────────

    @Test
    @DisplayName("Nhân viên: nhập lại nguyên file không đổi; sửa SĐT + thêm NV mới → UPDATE/CREATE và áp dụng, giữ phòng ban / bậc lương")
    void employees() throws Exception {
        var c = fixture.standardCompany();
        String code = one("SELECT employee_code FROM employees WHERE id = ?", c.emp(3).id());
        byte[] file = exportAndCheckUnchanged(c, "/api/v1/employees/export", "/api/v1/employees/preview-import");

        byte[] changed = edit(file, wb -> {
            Sheet sh = wb.getSheetAt(0);
            set(rowWhere(sh, 0, code), col(sh, 0, "Phone"), "0912345678");
            Row n = sh.createRow(sh.getLastRowNum() + 1);
            set(n, col(sh, 0, "Employee Code"), "NEW001");
            set(n, col(sh, 0, "Full Name"), "Trần Mới");
            set(n, col(sh, 0, "Email"), "new001@excel.test");
            set(n, col(sh, 0, "Join Date"), "01/11/2026");
            set(n, col(sh, 0, "Department (*)"), "KT");
            set(n, col(sh, 0, "Salary Grade"), "NGAY300");
        });
        JsonNode prev = preview(c, "/api/v1/employees/preview-import", changed);
        noProblems(prev);
        assertThat(actions(prev).stream().filter(a -> !a.equals("NO_CHANGE")).toList())
            .containsExactlyInAnyOrder("UPDATE", "CREATE");

        doImport(c, "/api/v1/employees/import", changed);
        assertThat(one("SELECT phone FROM employees WHERE id = ?", c.emp(3).id())).isEqualTo("0912345678");
        assertThat(one("SELECT sg.code FROM employees e JOIN salary_grades sg ON sg.id = e.salary_grade_id WHERE e.id = ?",
            c.emp(3).id())).isEqualTo("NGAY300");
        assertThat(one("SELECT d.code FROM employees e JOIN departments d ON d.id = e.department_id "
            + "WHERE e.employee_code = 'NEW001' AND e.company_id = ? AND e.deleted = 0", c.id)).isEqualTo("KT");

        exportAndCheckUnchanged(c, "/api/v1/employees/export", "/api/v1/employees/preview-import");
    }

    @Test
    @DisplayName("Phòng ban + chức vụ: đổi tên phòng, thêm phòng con, thêm chức vụ → áp dụng")
    void departmentsAndPositions() throws Exception {
        var c = fixture.standardCompany();
        byte[] file = exportAndCheckUnchanged(c, "/api/v1/departments/export", "/api/v1/departments/preview-import");

        byte[] changed = edit(file, wb -> {
            Sheet d = wb.getSheetAt(0);
            set(rowWhere(d, 0, "KT"), col(d, 0, "Department Name"), "Kế toán tổng hợp");
            Row n = d.createRow(d.getLastRowNum() + 1);
            set(n, col(d, 0, "Department Code"), "KT2");
            set(n, col(d, 0, "Department Name"), "Kế toán chi phí");
            set(n, col(d, 0, "Parent Dept Code"), "KT");
            Sheet p = wb.getSheetAt(1);
            Row pr = p.createRow(p.getLastRowNum() + 1);
            set(pr, col(p, 0, "Position Code"), "TP");
            set(pr, col(p, 0, "Position Name"), "Trưởng phòng");
            set(pr, col(p, 0, "Department Code"), "KT");
        });
        JsonNode prev = preview(c, "/api/v1/departments/preview-import", changed);
        noProblems(prev);
        assertThat(actions(prev)).contains("UPDATE", "CREATE");
        doImport(c, "/api/v1/departments/import", changed);
        assertThat(one("SELECT name FROM departments WHERE company_id = ? AND code = 'KT' AND deleted = 0", c.id))
            .isEqualTo("Kế toán tổng hợp");
        assertThat(one("SELECT p.code FROM departments d JOIN departments p ON p.id = d.parent_id "
            + "WHERE d.company_id = ? AND d.code = 'KT2' AND d.deleted = 0", c.id)).isEqualTo("KT");

        JsonNode pp = preview(c, "/api/v1/departments/positions/preview-import", changed);
        noProblems(pp);
        assertThat(actions(pp)).containsExactly("CREATE");
        doImport(c, "/api/v1/departments/positions/import", changed);
        assertThat(one("SELECT p.name FROM positions p JOIN departments d ON d.id = p.department_id "
            + "WHERE d.company_id = ? AND p.code = 'TP' AND p.deleted = 0", c.id)).isEqualTo("Trưởng phòng");

        exportAndCheckUnchanged(c, "/api/v1/departments/export", "/api/v1/departments/preview-import");
        exportAndCheckUnchanged(c, "/api/v1/departments/export", "/api/v1/departments/positions/preview-import");
    }

    @Test
    @DisplayName("Danh sách ca: đổi tên + giờ kết thúc ca → áp dụng")
    void shifts() throws Exception {
        var c = fixture.standardCompany();
        byte[] file = exportAndCheckUnchanged(c, "/api/v1/shifts/export-list", "/api/v1/shifts/preview-import");
        byte[] changed = edit(file, wb -> {
            Sheet s = wb.getSheetAt(0);
            Row r = rowWhere(s, 0, "CHIEU");
            set(r, col(s, 0, "Shift Name"), "Ca chiều mới");
            set(r, col(s, 0, "End Time"), "18:00");
        });
        JsonNode prev = preview(c, "/api/v1/shifts/preview-import", changed);
        noProblems(prev);
        assertThat(actions(prev).stream().filter(a -> !a.equals("NO_CHANGE")).toList()).containsExactly("UPDATE");
        doImport(c, "/api/v1/shifts/import", changed);
        assertThat(one("SELECT CONCAT(name, '|', TIME_FORMAT(end_time, '%H:%i')) FROM work_shifts "
            + "WHERE company_id = ? AND code = 'CHIEU' AND active = 1", c.id)).isEqualTo("Ca chiều mới|18:00");
        exportAndCheckUnchanged(c, "/api/v1/shifts/export-list", "/api/v1/shifts/preview-import");
    }

    @Test
    @DisplayName("Phân ca bảng ngang: đổi ca một ô, xếp ca ô trống → áp dụng")
    void shiftAssignments() throws Exception {
        var c = fixture.standardCompany();
        var e1 = c.emp(1);
        var e2 = c.emp(2);
        c.assign(e1, "HC", D1);
        c.assign(e2, "HC", D1);
        String code1 = one("SELECT employee_code FROM employees WHERE id = ?", e1.id());
        String code2 = one("SELECT employee_code FROM employees WHERE id = ?", e2.id());
        String url = "/api/v1/shifts/export?year=2026&month=11";
        byte[] file = exportAndCheckUnchanged(c, url, "/api/v1/shifts/preview-import-assignments");

        byte[] changed = edit(file, wb -> {
            Sheet s = wb.getSheetAt(0);
            set(rowWhere(s, 0, code1), col(s, 0, "2/11"), "CHIEU");     // HC → CHIEU
            set(rowWhere(s, 0, code2), col(s, 0, "3/11"), "SANG");      // ô trống → SANG
        });
        JsonNode prev = preview(c, "/api/v1/shifts/preview-import-assignments", changed);
        noProblems(prev);
        assertThat(actions(prev).stream().filter(a -> !a.equals("NO_CHANGE")).toList()).isNotEmpty();
        doImport(c, "/api/v1/shifts/import-assignments", changed);
        assertThat(one("SELECT GROUP_CONCAT(w.code) FROM shift_assignments a JOIN work_shifts w ON w.id = a.shift_id "
            + "WHERE a.employee_id = ? AND a.work_date = ? AND a.deleted = 0", e1.id(), D1)).isEqualTo("CHIEU");
        assertThat(one("SELECT GROUP_CONCAT(w.code) FROM shift_assignments a JOIN work_shifts w ON w.id = a.shift_id "
            + "WHERE a.employee_id = ? AND a.work_date = ? AND a.deleted = 0", e2.id(), D1.plusDays(1))).isEqualTo("SANG");
        exportAndCheckUnchanged(c, url, "/api/v1/shifts/preview-import-assignments");
    }

    @Test
    @DisplayName("Ngày lễ: đổi tên, thêm ngày → áp dụng")
    void holidays() throws Exception {
        var c = fixture.standardCompany();
        byte[] file = exportAndCheckUnchanged(c, "/api/v1/holidays/export?year=2026", "/api/v1/holidays/preview-import");
        byte[] changed = edit(file, wb -> {
            Sheet s = wb.getSheetAt(0);
            set(rowWhere(s, 0, "2026-01-01"), col(s, 0, "Holiday Name"), "Tết Dương lịch (công ty)");
            Row n = s.createRow(s.getLastRowNum() + 1);
            set(n, col(s, 0, "Date"), "2026-12-24");
            set(n, col(s, 0, "Holiday Name"), "Giáng sinh");
            set(n, col(s, 0, "Type"), "HOLIDAY");
            set(n, col(s, 0, "Paid"), "1");
        });
        JsonNode prev = preview(c, "/api/v1/holidays/preview-import", changed);
        noProblems(prev);
        assertThat(actions(prev)).contains("UPDATE", "CREATE");
        doImport(c, "/api/v1/holidays/import", changed);
        assertThat(one("SELECT name FROM holidays WHERE company_id = ? AND holiday_date = '2026-12-24' AND deleted = 0", c.id)).isEqualTo("Giáng sinh");
        assertThat(one("SELECT name FROM holidays WHERE company_id = ? AND holiday_date = '2026-01-01' AND deleted = 0", c.id))
            .isEqualTo("Tết Dương lịch (công ty)");
        exportAndCheckUnchanged(c, "/api/v1/holidays/export?year=2026", "/api/v1/holidays/preview-import");
    }

    @Test
    @DisplayName("Chấm công + bảng công: nhập lại nguyên file không đổi; in giá trị ô để kiểm định dạng")
    void attendanceFormats() throws Exception {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        c.assign(e, "HC", D1);
        clock.set(D1.atTime(7, 55));
        api.post(c.tokenOf(e), "/api/v1/attendances/self/check-in", Map.of()).expectOk();
        clock.set(D1.atTime(17, 5));
        api.post(c.tokenOf(e), "/api/v1/attendances/self/check-out", Map.of()).expectOk();
        clock.reset();
        String code = one("SELECT employee_code FROM employees WHERE id = ?", e.id());

        byte[] att = exportAndCheckUnchanged(c, "/api/v1/attendances/export?from=2026-11-01&to=2026-11-30",
            "/api/v1/attendances/preview-import");
        try (XSSFWorkbook wb = new XSSFWorkbook(new ByteArrayInputStream(att))) {
            Sheet s = wb.getSheetAt(0);
            System.out.println("CELL attendance " + code + " 2/11 = '"
                + FMT.formatCellValue(rowWhere(s, 0, code).getCell(col(s, 0, "2/11"))) + "'");
        }
        byte[] ts = exportAndCheckUnchanged(c, "/api/v1/attendances/export-timesheet?employeeId=" + e.id()
            + "&from=2026-11-01&to=2026-11-30", "/api/v1/attendances/preview-import-timesheet");
        try (XSSFWorkbook wb = new XSSFWorkbook(new ByteArrayInputStream(ts))) {
            Sheet s = wb.getSheetAt(0);
            for (int r = 0; r <= 4; r++) {
                Row row = s.getRow(r); if (row == null) continue;
                List<String> cells = new ArrayList<>();
                for (Cell cell : row) cells.add(FMT.formatCellValue(cell));
                System.out.println("CELL timesheet r" + r + " " + cells);
            }
        }
    }

    String effectiveTimes(long empId, LocalDate d) {
        return one("SELECT CONCAT(COALESCE(TIME_FORMAT(override_check_in, '%H:%i'), TIME_FORMAT(check_in, '%H:%i')), '~', "
            + "COALESCE(TIME_FORMAT(override_check_out, '%H:%i'), TIME_FORMAT(check_out, '%H:%i'))) "
            + "FROM attendances WHERE employee_id = ? AND date = ? AND deleted = 0", empId, d);
    }

    Fixture.TestCompany companyWithPunch(Fixture.Emp[] out) {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        out[0] = e;
        c.assign(e, "HC", D1);
        clock.set(D1.atTime(7, 55));
        api.post(c.tokenOf(e), "/api/v1/attendances/self/check-in", Map.of()).expectOk();
        clock.set(D1.atTime(17, 5));
        api.post(c.tokenOf(e), "/api/v1/attendances/self/check-out", Map.of()).expectOk();
        clock.reset();
        return c;
    }

    @Test
    @DisplayName("Chấm công (bảng tháng): sửa giờ vào/ra một ô → UPDATE và áp dụng")
    void attendanceEdit() throws Exception {
        Fixture.Emp[] holder = new Fixture.Emp[1];
        var c = companyWithPunch(holder);
        var e = holder[0];
        String code = one("SELECT employee_code FROM employees WHERE id = ?", e.id());
        String url = "/api/v1/attendances/export?from=2026-11-01&to=2026-11-30";
        byte[] file = exportAndCheckUnchanged(c, url, "/api/v1/attendances/preview-import");
        byte[] changed = edit(file, wb -> {
            Sheet s = wb.getSheetAt(0);
            set(rowWhere(s, 0, code), col(s, 0, "2/11"), "08:10~17:00");
        });
        JsonNode prev = preview(c, "/api/v1/attendances/preview-import", changed);
        noProblems(prev);
        assertThat(actions(prev)).containsExactly("UPDATE");
        doImport(c, "/api/v1/attendances/import", changed);
        assertThat(effectiveTimes(e.id(), D1)).isEqualTo("08:10~17:00");
        exportAndCheckUnchanged(c, url, "/api/v1/attendances/preview-import");
    }

    @Test
    @DisplayName("Bảng công một nhân viên: sửa giờ vào → UPDATE và áp dụng")
    void timesheetEdit() throws Exception {
        Fixture.Emp[] holder = new Fixture.Emp[1];
        var c = companyWithPunch(holder);
        var e = holder[0];
        String url = "/api/v1/attendances/export-timesheet?employeeId=" + e.id() + "&from=2026-11-01&to=2026-11-30";
        byte[] file = exportAndCheckUnchanged(c, url, "/api/v1/attendances/preview-import-timesheet");
        byte[] changed = edit(file, wb -> {
            Sheet s = wb.getSheetAt(0);
            Row day2 = rowWhere(s, 0, "2");
            set(day2, col(s, 0, "Check-in"), "08:05");
        });
        JsonNode prev = preview(c, "/api/v1/attendances/preview-import-timesheet", changed);
        noProblems(prev);
        assertThat(actions(prev)).containsExactly("UPDATE");
        doImport(c, "/api/v1/attendances/import-timesheet", changed);
        assertThat(effectiveTimes(e.id(), D1)).isEqualTo("08:05~17:05");
        exportAndCheckUnchanged(c, url, "/api/v1/attendances/preview-import-timesheet");
    }

    @Test
    @DisplayName("Bảng công xuất tiếng Việt: đầu cột tiếng Việt vẫn nhập lại được")
    void timesheetVietnamese() throws Exception {
        Fixture.Emp[] holder = new Fixture.Emp[1];
        var c = companyWithPunch(holder);
        var e = holder[0];
        c.assign(e, "HC", D1.plusDays(1));      // ngày có ca, chưa chấm
        byte[] file = api.download(c.adminToken,
            "/api/v1/attendances/export-timesheet?employeeId=" + e.id() + "&from=2026-11-01&to=2026-11-30", "vi");
        assertThat(actions(preview(c, "/api/v1/attendances/preview-import-timesheet", file))).isEmpty();
        // Nhập nguyên file: không ghi đè giờ, không tạo bản ghi rỗng cho ngày có ca chưa chấm
        long before = Long.parseLong(one("SELECT COUNT(*) FROM attendances WHERE employee_id = ? AND deleted = 0", e.id()));
        doImport(c, "/api/v1/attendances/import-timesheet", file);
        assertThat(one("SELECT COUNT(*) FROM attendances WHERE employee_id = ? AND deleted = 0 AND (override_check_in IS NOT NULL "
            + "OR override_check_out IS NOT NULL OR override_break_minutes IS NOT NULL)", e.id())).isEqualTo("0");
        assertThat(Long.parseLong(one("SELECT COUNT(*) FROM attendances WHERE employee_id = ? AND deleted = 0", e.id()))).isEqualTo(before);
        byte[] changed = edit(file, wb -> {
            Sheet s = wb.getSheetAt(0);
            set(rowWhere(s, 0, "2"), col(s, 0, "Check-out"), "17:30");
        });
        JsonNode prev = preview(c, "/api/v1/attendances/preview-import-timesheet", changed);
        assertThat(actions(prev)).containsExactly("UPDATE");
        doImport(c, "/api/v1/attendances/import-timesheet", changed);
        assertThat(effectiveTimes(e.id(), D1)).isEqualTo("07:55~17:30");
    }

    @Test
    @DisplayName("Chấm công theo ngày (vi + en): sửa giờ ra → UPDATE và áp dụng")
    void dayViewEdit() throws Exception {
        for (String lang : List.of("vi", "en")) {
            Fixture.Emp[] holder = new Fixture.Emp[1];
            var c = companyWithPunch(holder);
            var e = holder[0];
            String code = one("SELECT employee_code FROM employees WHERE id = ?", e.id());
            byte[] file = api.download(c.adminToken, "/api/v1/attendances/export-day-view?date=" + D1, lang);
            assertThat(actions(preview(c, "/api/v1/attendances/preview-import-timesheet", file))).as(lang).isEmpty();
            String newOut = lang.equals("vi") ? "17:20" : "17:40";
            byte[] changed = edit(file, wb -> {
                Sheet s = wb.getSheetAt(0);
                Row target = null;
                for (Row r : s) if (r.getRowNum() > 1 && FMT.formatCellValue(r.getCell(0)).startsWith(code + " - ")) target = r;
                assertThat(target).as("dòng " + code).isNotNull();
                set(target, col(s, 1, "Check-out"), newOut);
            });
            JsonNode prev = preview(c, "/api/v1/attendances/preview-import-timesheet", changed);
            assertThat(actions(prev)).as(lang).containsExactly("UPDATE");
            doImport(c, "/api/v1/attendances/import-timesheet", changed);
            assertThat(effectiveTimes(e.id(), D1)).as(lang).isEqualTo("07:55~" + newOut);
        }
    }

    @Test
    @DisplayName("Excel chung: xuất mọi loại → nhập lại không đổi; sửa SĐT nhân viên + tên ca → áp dụng")
    void universal() throws Exception {
        var c = fixture.standardCompany();
        JsonNode meta = api.get(c.adminToken, "/api/v1/excel/meta").expectOk().body();
        List<String> types = new ArrayList<>();
        meta.fieldNames().forEachRemaining(types::add);
        var r = mvc.perform(MockMvcRequestBuilders.post("/api/v1/excel/export")
                .header("Authorization", "Bearer " + c.adminToken)
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("types", types))))
            .andReturn().getResponse();
        assertThat(r.getStatus()).isEqualTo(200);
        byte[] all = r.getContentAsByteArray();

        JsonNode prev = preview(c, "/api/v1/excel/preview-import", all);
        noProblems(prev);
        assertThat(diffs(prev)).as("nhập lại nguyên file Excel chung").isEmpty();

        String code = one("SELECT employee_code FROM employees WHERE id = ?", c.emp(4).id());
        byte[] changed = edit(all, wb -> {
            Sheet emp = null, sh = null;
            for (Sheet s : wb) {
                String h = FMT.formatCellValue(s.getRow(0).getCell(1));
                if (emp == null && h.startsWith("Employee Code") && s.getSheetName().startsWith("Employee")) emp = s;
                if (sh == null && h.startsWith("Shift Code")) sh = s;
            }
            assertThat(emp).as("sheet nhân viên").isNotNull();
            assertThat(sh).as("sheet ca").isNotNull();
            set(rowWhere(emp, 1, code), col(emp, 0, "Phone"), "0987654321");
            set(rowWhere(sh, 1, "SANG"), col(sh, 0, "Shift Name"), "Ca sáng sớm");
        });
        JsonNode prev2 = preview(c, "/api/v1/excel/preview-import", changed);
        noProblems(prev2);
        assertThat(diffs(prev2)).hasSize(2);
        doImport(c, "/api/v1/excel/import", changed);
        assertThat(one("SELECT phone FROM employees WHERE id = ?", c.emp(4).id())).isEqualTo("0987654321");
        assertThat(one("SELECT name FROM work_shifts WHERE company_id = ? AND code = 'SANG' AND active = 1", c.id))
            .isEqualTo("Ca sáng sớm");
    }

    // ── File mẫu (GET …/template): tiêu đề đúng cột nhập, sheet Hướng dẫn cuối, nhập nguyên file = không đổi ──

    /** Điền giá trị vào dòng {@code rowIdx} theo cột có tiêu đề bắt đầu bằng {@code header}. */
    static void fill(Sheet sh, int rowIdx, String header, String value) {
        Row r = sh.getRow(rowIdx) != null ? sh.getRow(rowIdx) : sh.createRow(rowIdx);
        set(r, col(sh, 0, header), value);
    }

    byte[] template(Fixture.TestCompany c, String url, String lang, int dataSheets) throws Exception {
        byte[] file = api.download(c.adminToken, url, lang);
        try (var wb = new XSSFWorkbook(new ByteArrayInputStream(file))) {
            assertThat(wb.getNumberOfSheets()).as(url).isEqualTo(dataSheets + 1);
            assertThat(wb.getActiveSheetIndex()).isEqualTo(dataSheets);
            assertThat(wb.getSheetName(dataSheets)).isEqualTo(lang.equals("vi") ? "Hướng dẫn" : "Guide");
            for (int i = 0; i < dataSheets; i++) assertThat(wb.getSheetAt(i).getLastRowNum()).as("chỉ dòng tiêu đề").isZero();
        }
        return file;
    }

    @Test
    @DisplayName("File mẫu hợp đồng (en): sheet Hướng dẫn không bị đọc thành phụ cấp; điền 1 hợp đồng → tạo")
    void contractTemplate() throws Exception {
        var c = fixture.standardCompany();
        byte[] file = template(c, "/api/v1/contracts/template", "en", 2);
        assertThat(actions(preview(c, "/api/v1/contracts/preview-import", file))).isEmpty();
        byte[] filled = edit(file, wb -> {
            Sheet s = wb.getSheetAt(0);
            fill(s, 1, "Contract No", "HD-MAU-1");
            fill(s, 1, "Employee Code", c.emp(2).code());
            fill(s, 1, "Type", "INDEFINITE");
            fill(s, 1, "Start Date", "2026-11-01");
            fill(s, 1, "Base Salary", "12000000");
            wb.removeSheetAt(1);        // chỉ hợp đồng: sheet thứ 2 giờ là Hướng dẫn → phụ cấp giữ nguyên
        });
        JsonNode prev = preview(c, "/api/v1/contracts/preview-import", filled);
        noProblems(prev);
        assertThat(actions(prev)).containsExactly("CREATE");
        doImport(c, "/api/v1/contracts/import", filled);
        assertThat(one("SELECT COUNT(*) FROM labor_contracts WHERE company_id = ? AND contract_no = 'HD-MAU-1' AND deleted = 0",
            c.id)).isEqualTo("1");
    }

    @Test
    @DisplayName("File mẫu ngày lễ: điền 1 ngày → tạo")
    void holidayTemplate() throws Exception {
        var c = fixture.standardCompany();
        byte[] file = template(c, "/api/v1/holidays/template", "vi", 1);
        byte[] filled = edit(file, wb -> {
            Sheet s = wb.getSheetAt(0);
            fill(s, 1, "Ngày", "2026-12-24");
            fill(s, 1, "Tên ngày lễ", "Nghỉ Giáng sinh");
        });
        JsonNode prev = preview(c, "/api/v1/holidays/preview-import", filled);
        noProblems(prev);
        assertThat(actions(prev)).contains("CREATE");
        doImport(c, "/api/v1/holidays/import", filled);
        assertThat(one("SELECT name FROM holidays WHERE company_id = ? AND holiday_date = '2026-12-24' AND deleted = 0", c.id))
            .isEqualTo("Nghỉ Giáng sinh");
    }

    @Test
    @DisplayName("File mẫu Excel chung: cột Lệnh, nhập nguyên mẫu không đổi; điền phòng ban + nhân viên → tạo đúng thứ tự")
    void universalTemplate() throws Exception {
        var c = fixture.standardCompany();
        byte[] file = api.download(c.adminToken, "/api/v1/excel/template", "vi");
        int sheets;
        try (var wb = new XSSFWorkbook(new ByteArrayInputStream(file))) {
            sheets = wb.getNumberOfSheets();
            assertThat(wb.getSheetName(sheets - 1)).isEqualTo("Hướng dẫn");
            assertThat(FMT.formatCellValue(wb.getSheet("Phòng ban").getRow(0).getCell(0))).isEqualTo("Lệnh");
        }
        assertThat(actions(preview(c, "/api/v1/excel/preview-import", file))).isEmpty();
        try (var wb = new XSSFWorkbook(new ByteArrayInputStream(file))) {     // hướng dẫn: Mã NV (*) không bắt buộc khi thêm mới
            Sheet g = wb.getSheet("Hướng dẫn");
            Row codeRow = null;
            boolean inEmployees = false;
            for (Row r : g) {
                String a = FMT.formatCellValue(r.getCell(0));
                if (a.startsWith("Sheet: ")) inEmployees = a.startsWith("Sheet: Nhân viên");
                if (inEmployees && codeRow == null && a.startsWith("Mã NV")) codeRow = r;
            }
            assertThat(FMT.formatCellValue(codeRow.getCell(1))).isEmpty();
            assertThat(FMT.formatCellValue(codeRow.getCell(3))).contains("tự cấp");
        }
        byte[] filled = edit(file, wb -> {
            Sheet d = wb.getSheet("Phòng ban");
            fill(d, 1, "Lệnh", "MERGE");
            fill(d, 1, "Mã phòng ban", "CH01");
            fill(d, 1, "Tên phòng ban", "Cửa hàng Quận 1");
            Sheet e = null;
            for (Sheet sh : wb) if (sh.getSheetName().startsWith("Nhân viên")) { e = sh; break; }
            fill(e, 1, "Lệnh", "MERGE");
            fill(e, 1, "Họ và tên", "Chung Mẫu");
            fill(e, 1, "Email", "chung.mau@test.local");
            fill(e, 1, "Phòng ban", "CH01");
        });
        JsonNode prev = preview(c, "/api/v1/excel/preview-import", filled);
        noProblems(prev);
        assertThat(actions(prev)).containsExactly("MERGE", "MERGE");
        doImport(c, "/api/v1/excel/import", filled);
        assertThat(one("SELECT d.code FROM employees e JOIN departments d ON d.id = e.department_id "
            + "WHERE e.company_id = ? AND e.email = 'chung.mau@test.local' AND e.deleted = 0", c.id)).isEqualTo("CH01");
        // Chỉ chọn một module
        byte[] one = api.download(c.adminToken, "/api/v1/excel/template?types=department", "en");
        try (var wb = new XSSFWorkbook(new ByteArrayInputStream(one))) {
            assertThat(wb.getNumberOfSheets()).isEqualTo(2);
            assertThat(wb.getSheetName(1)).isEqualTo("Guide");
        }
    }
}
