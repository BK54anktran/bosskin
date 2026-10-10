package com.bosskin.it;

import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Bước E: nhập dữ liệu thật cho công ty mới bằng Excel chung (/api/v1/excel). Một file nhiều sheet phải nhập theo
 * thứ tự phụ thuộc, nhập lại cùng file không tạo trùng, xem trước báo trước email đã dùng.
 */
class OnboardingImportTest extends IntegrationTest {

    @Autowired org.springframework.test.web.servlet.MockMvc mvc;
    @Autowired com.fasterxml.jackson.databind.ObjectMapper json;
    @Autowired org.springframework.jdbc.core.JdbcTemplate jdbc;

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 10, 9, 0);

    /** Sheet trong file mẫu: tên sheet + header lấy từ file xuất (khớp đúng bản đang chạy), dòng theo tên cột. */
    private record SheetData(String type, List<Map<String, Object>> rows) {}

    private byte[] buildFile(Fixture.TestCompany c, List<SheetData> sheets) throws Exception {
        List<String> types = sheets.stream().map(SheetData::type).toList();
        byte[] export = exportBytes(c, types);
        try (XSSFWorkbook src = new XSSFWorkbook(new ByteArrayInputStream(export));
             XSSFWorkbook out = new XSSFWorkbook()) {
            for (int i = 0; i < src.getNumberOfSheets(); i++) {
                Sheet s = src.getSheetAt(i);
                SheetData data = sheets.get(i);
                List<String> headers = new ArrayList<>();
                for (Cell h : s.getRow(0)) headers.add(h.getStringCellValue());
                Sheet o = out.createSheet(s.getSheetName());
                Row hr = o.createRow(0);
                for (int k = 0; k < headers.size(); k++) hr.createCell(k).setCellValue(headers.get(k));
                int r = 1;
                for (Map<String, Object> row : data.rows()) {
                    Row orow = o.createRow(r++);
                    orow.createCell(0).setCellValue("MERGE");
                    for (var e : row.entrySet()) {
                        int col = headers.indexOf(e.getKey());
                        assertThat(col).as("cột '%s' trong sheet %s: %s", e.getKey(), s.getSheetName(), headers).isPositive();
                        orow.createCell(col).setCellValue(String.valueOf(e.getValue()));
                    }
                }
            }
            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            out.write(bos);
            return bos.toByteArray();
        }
    }

    private byte[] exportBytes(Fixture.TestCompany c, List<String> types) throws Exception {
        var r = mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .post("/api/v1/excel/export").header("Authorization", "Bearer " + c.adminToken)
                .header("Accept-Language", "vi")
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("types", types))))
            .andReturn().getResponse();
        assertThat(r.getStatus()).isEqualTo(200);
        return r.getContentAsByteArray();
    }

    private static Map<String, Object> row(Object... kv) {
        Map<String, Object> m = new LinkedHashMap<>();
        for (int i = 0; i < kv.length; i += 2) m.put((String) kv[i], kv[i + 1]);
        return m;
    }

    private List<JsonNode> preview(Fixture.TestCompany c, byte[] file, String type) {
        JsonNode body = api.upload(c.adminToken, "/api/v1/excel/preview-import", "f.xlsx", file).expectOk().body();
        List<JsonNode> out = new ArrayList<>();
        body.path(type).forEach(out::add);
        return out;
    }

    private String importSummary(Fixture.TestCompany c, byte[] file) throws Exception {
        var r = mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .multipart("/api/v1/excel/import")
                .file(new org.springframework.mock.web.MockMultipartFile("file", "f.xlsx",
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", file))
                .header("Authorization", "Bearer " + c.adminToken))
            .andReturn().getResponse();
        assertThat(r.getStatus()).isEqualTo(200);
        return r.getHeader("X-Import-Summary");
    }

    private List<SheetData> onboardingSheets() {
        return List.of(
            // Thứ tự sheet trong file cố ý ngược: hệ thống vẫn phải nhập phòng ban trước nhân viên
            new SheetData("department", List.of(row("Mã phòng ban (*)", "XUONG2", "Tên phòng ban (*)", "Xưởng 2"))),
            new SheetData("employee", List.of(row("Mã NV (*)", "NV901", "Họ và tên (*)", "Phạm Văn Lực",
                "Email (*)", "luc901@onboard.test", "Phòng ban (*)", "XUONG2", "Ngày vào làm", "01/11/2026"))),
            new SheetData("leave_grant", List.of(row("Mã NV (*)", "NV901", "Mã loại phép (*)", "PN",
                "Số ngày phép", "5", "Ngày cấp (*)", "01/11/2026", "Hiệu lực đến", "31/12/2026"))),
            new SheetData("shift_assignment", List.of(row("Mã NV (*)", "NV901", "Ngày (*)", "02/11/2026",
                "Mã ca (*)", "HC")))
        );
    }

    private long count(String sql, Object... args) {
        Long n = jdbc.queryForObject(sql, Long.class, args);
        return n == null ? 0 : n;
    }

    @Test
    @DisplayName("Một file phòng ban + nhân viên + số dư phép + phân ca nhập được hết; nhập lại không tạo trùng, sửa số phép thì cập nhật")
    void one_file_onboarding_is_ordered_and_idempotent() throws Exception {
        clock.set(NOW);
        var c = fixture.standardCompany();
        byte[] file = buildFile(c, onboardingSheets());

        assertThat(importSummary(c, file)).isEqualTo("{\"ok\":4,\"error\":0,\"skip\":0}");
        String emp = "SELECT e.id FROM employees e WHERE e.employee_code = 'NV901' AND e.company_id = ?";
        long empId = jdbc.queryForObject(emp, Long.class, c.id);
        String grants = "SELECT COUNT(*) FROM leave_grants WHERE employee_id = ?";
        String assigns = "SELECT COUNT(*) FROM shift_assignments WHERE employee_id = ? AND deleted = false";
        assertThat(count(grants, empId)).isEqualTo(1);
        assertThat(count(assigns, empId)).isEqualTo(1);

        // Nhập lại đúng file: không nhân đôi số dư phép / phân ca; xem trước báo "không đổi" (không có tóm tắt)
        assertThat(preview(c, file, "leave_grant").get(0).path("summary").isNull()).isTrue();
        assertThat(importSummary(c, file)).isEqualTo("{\"ok\":4,\"error\":0,\"skip\":0}");
        assertThat(count(grants, empId)).isEqualTo(1);
        assertThat(count(assigns, empId)).isEqualTo(1);

        // Sửa số ngày phép 5 → 7: cập nhật đúng quỹ đó
        List<SheetData> changed = new ArrayList<>(onboardingSheets());
        changed.set(2, new SheetData("leave_grant", List.of(row("Mã NV (*)", "NV901", "Mã loại phép (*)", "PN",
            "Số ngày phép", "7", "Ngày cấp (*)", "01/11/2026", "Hiệu lực đến", "31/12/2026"))));
        byte[] file2 = buildFile(c, changed);
        assertThat(preview(c, file2, "leave_grant").get(0).path("summary").asText())
            .isEqualTo("excel.col.leaveGrant.grantDays:5→7");
        importSummary(c, file2);
        assertThat(count(grants, empId)).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT grant_days FROM leave_grants WHERE employee_id = ?",
            java.math.BigDecimal.class, empId)).isEqualByComparingTo("7");
    }

    @Test
    @DisplayName("Xem trước nhân viên mới báo ngay email đã có tài khoản và phòng ban chưa có")
    void preview_reports_email_in_use_and_missing_department() throws Exception {
        clock.set(NOW);
        var c = fixture.standardCompany();
        byte[] file = buildFile(c, List.of(new SheetData("employee", List.of(
            row("Mã NV (*)", "NV902", "Họ và tên (*)", "Trùng Email", "Email (*)", c.emp(0).email(), "Phòng ban (*)", "KT"),
            row("Mã NV (*)", "NV903", "Họ và tên (*)", "Sai Phòng", "Email (*)", "nv903@onboard.test", "Phòng ban (*)", "KHONGCO"),
            row("Mã NV (*)", "NV904", "Họ và tên (*)", "Hợp Lệ", "Email (*)", "nv904@onboard.test", "Phòng ban (*)", "KT")))));
        List<JsonNode> rows = preview(c, file, "employee");
        assertThat(rows.get(0).path("error").asText()).isEqualTo("error.import.email_in_use|" + c.emp(0).email());
        assertThat(rows.get(1).path("error").asText()).startsWith("error.import.department_missing|KHONGCO");
        assertThat(rows.get(2).path("error").isNull()).isTrue();
    }
}
