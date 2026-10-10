package com.bosskin.it;

import com.bosskin.audit.AuditLogRepository;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** Bước N: tài liệu nhân sự — link ký tạm, phạm vi, sắp hết hạn, thiếu bắt buộc, NV tự gửi chờ duyệt. */
class DocumentTest extends IntegrationTest {

    @Autowired AuditLogRepository auditLogRepository;

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 10, 9, 0);
    private static final byte[] PDF = "%PDF-1.4 test".getBytes(StandardCharsets.UTF_8);

    private long typeId(Fixture.TestCompany c, String code) {
        for (JsonNode t : api.get(c.adminToken, "/api/v1/document-types").expectOk().body()) {
            if (code.equals(t.get("code").asText())) return t.get("id").asLong();
        }
        throw new IllegalStateException("không có loại " + code);
    }

    private Map<String, String> params(Fixture.Emp e, long typeId, String expiresOn) {
        Map<String, String> m = new LinkedHashMap<>();
        if (e != null) m.put("employeeId", String.valueOf(e.id()));
        m.put("typeId", String.valueOf(typeId));
        if (expiresOn != null) m.put("expiresOn", expiresOn);
        return m;
    }

    private long upload(Fixture.TestCompany c, Fixture.Emp e, String code, String expiresOn) {
        return api.uploadWith(c.adminToken, "/api/v1/employee-documents", code + ".pdf", "application/pdf", PDF,
            params(e, typeId(c, code), expiresOn)).expectOk().id();
    }

    @Test
    @DisplayName("Công ty mới có sẵn 6 loại tài liệu; link tải ký tạm dùng được, hết hạn sau 5 phút → 410, sửa token → 403")
    void upload_link_expires() {
        clock.set(NOW);
        var c = fixture.standardCompany();
        assertThat(api.get(c.adminToken, "/api/v1/document-types").expectOk().body()).hasSize(6);
        var e = c.emp(3);

        // Loại có hạn mà thiếu ngày hết hạn → lỗi
        assertThat(api.uploadWith(c.adminToken, "/api/v1/employee-documents", "a.pdf", "application/pdf", PDF,
            params(e, typeId(c, "CCCD"), null)).raw()).contains("error.document.expiry_required");
        // Sai kiểu file
        assertThat(api.uploadWith(c.adminToken, "/api/v1/employee-documents", "a.exe", "application/x-msdownload", PDF,
            params(e, typeId(c, "SYLL"), null)).raw()).contains("error.s3.invalid_type");

        long id = upload(c, e, "CCCD", "2035-01-01");
        JsonNode list = api.get(c.adminToken, "/api/v1/employee-documents?employeeId=" + e.id()).expectOk().body();
        assertThat(list).hasSize(1);
        assertThat(list.get(0).get("status").asText()).isEqualTo("APPROVED");

        String url = api.get(c.adminToken, "/api/v1/employee-documents/" + id + "/link").expectOk().text("url");
        assertThat(url).startsWith("/api/v1/public/document-files?t=");
        var ok = api.rawGet(url);
        assertThat(ok.getKey()).isEqualTo(200);
        assertThat(ok.getValue()).isEqualTo(PDF);
        assertThat(auditLogRepository.findAll()).anyMatch(a -> "DOCUMENT_VIEW".equals(a.getAction()));

        // Sửa chữ ký → 403
        assertThat(api.rawGet(url.substring(0, url.length() - 2) + "AA").getKey()).isEqualTo(403);
        // Quá 5 phút → 410
        clock.set(NOW.plusMinutes(10));
        assertThat(api.rawGet(url).getKey()).isEqualTo(410);
    }

    @Test
    @DisplayName("Quản lý tài liệu chỉ phòng KT: xem được NV KT, NV SX → 403; NV thường không xem được tài liệu người khác")
    void scope() {
        clock.set(NOW);
        var c = fixture.standardCompany();
        long kt = c.departments.get("KT");
        var ktEmp = c.emp(3);
        var sxEmp = c.emp(6);
        long docSx = upload(c, sxEmp, "SYLL", null);
        upload(c, ktEmp, "SYLL", null);

        long roleId = api.post(c.adminToken, "/api/v1/roles", Map.of(
            "name", "Tài liệu KT", "description", "test",
            "permissions", List.of("EMPLOYEE_VIEW", "EMPLOYEE_DOCUMENT_VIEW"), "roleViewAllCompany", true,
            "deptScopes", Map.of("EMPLOYEE_DOCUMENT_VIEW", List.of(kt)))).expectOk().id();
        var u = c.emp(4);
        api.put(c.adminToken, "/api/v1/users/" + u.userId() + "/roles", Map.of("roleIds", List.of(roleId))).expectOk();
        String token = c.tokenOf(u);

        api.get(token, "/api/v1/employee-documents?employeeId=" + ktEmp.id()).expectOk();
        assertThat(api.get(token, "/api/v1/employee-documents?employeeId=" + sxEmp.id()).status()).isEqualTo(403);
        assertThat(api.get(token, "/api/v1/employee-documents/" + docSx + "/link").status()).isEqualTo(403);
        // Không có EDIT → không tải lên được
        assertThat(api.uploadWith(token, "/api/v1/employee-documents", "a.pdf", "application/pdf", PDF,
            params(ktEmp, typeId(c, "SYLL"), null)).status()).isEqualTo(403);
        // Danh sách thiếu chỉ gồm NV trong phạm vi
        for (JsonNode m : api.get(token, "/api/v1/employee-documents/missing").expectOk().body()) {
            assertThat(c.employees.stream().filter(x -> x.id() == m.get("employeeId").asLong()).findFirst()
                .orElseThrow().departmentId()).isEqualTo(kt);
        }

        // NV thường
        String plain = c.tokenOf(c.emp(7));
        assertThat(api.get(plain, "/api/v1/employee-documents?employeeId=" + sxEmp.id()).status()).isEqualTo(403);
        assertThat(api.get(plain, "/api/v1/employee-documents/" + docSx + "/link").status()).isEqualTo(403);
        // Bản của mình qua /self cũng không lấy được tài liệu người khác
        assertThat(api.get(plain, "/api/v1/employee-documents/self/" + docSx + "/link").status()).isEqualTo(404);
    }

    @Test
    @DisplayName("CCCD hết hạn trong 20 ngày → danh sách sắp hết hạn + cảnh báo tổng quan; có bản mới thì hết cảnh báo")
    void expiring_and_dashboard() {
        clock.set(NOW);
        var c = fixture.standardCompany();
        var e = c.emp(5);
        upload(c, e, "CCCD", "2026-10-30");
        upload(c, c.emp(6), "CCCD", "2027-06-01");

        JsonNode exp = api.get(c.adminToken, "/api/v1/employee-documents/expiring").expectOk().body();
        assertThat(exp).hasSize(1);
        assertThat(exp.get(0).get("employeeId").asLong()).isEqualTo(e.id());
        assertThat(exp.get(0).get("daysToExpiry").asInt()).isEqualTo(20);

        JsonNode risks = api.get(c.adminToken, "/api/v1/dashboard/risks?date=2026-10-10").expectOk().body();
        assertThat(risks.get("documentExpiring")).hasSize(1);
        assertThat(risks.get("documentExpiring").get(0).get("daysLeft").asInt()).isEqualTo(20);

        // Bản mới còn hạn dài → bản cũ không còn cần thay
        upload(c, e, "CCCD", "2041-10-30");
        assertThat(api.get(c.adminToken, "/api/v1/employee-documents/expiring").expectOk().body()).isEmpty();
    }

    @Test
    @DisplayName("Thiếu tài liệu bắt buộc: NV chưa có CCCD/SYLL còn hạn nằm trong danh sách; đủ thì không")
    void missingRequired() {
        clock.set(NOW);
        var c = fixture.standardCompany();
        var full = c.emp(3);
        var partial = c.emp(4);
        upload(c, full, "CCCD", "2035-01-01");
        upload(c, full, "SYLL", null);
        upload(c, partial, "CCCD", "2026-01-01"); // đã hết hạn → vẫn tính là thiếu
        upload(c, partial, "SYLL", null);

        JsonNode missing = api.get(c.adminToken, "/api/v1/employee-documents/missing").expectOk().body();
        List<Long> ids = new ArrayList<>();
        missing.forEach(m -> ids.add(m.get("employeeId").asLong()));
        assertThat(ids).doesNotContain(full.id()).contains(partial.id(), c.emp(5).id());
        for (JsonNode m : missing) {
            if (m.get("employeeId").asLong() == partial.id()) {
                assertThat(m.get("missingTypes")).hasSize(1);
            }
        }
    }

    @Test
    @DisplayName("NV tự gửi tài liệu → chờ duyệt (chưa tính là có); HR duyệt → hết thiếu; không duyệt được bản của chính mình")
    void selfUpload_pendingUntilApproved() {
        clock.set(NOW);
        var c = fixture.standardCompany();
        var e = c.emp(6);
        String token = c.tokenOf(e);

        assertThat(api.get(token, "/api/v1/document-types").expectOk().body()).isNotEmpty();
        long id = api.uploadWith(token, "/api/v1/employee-documents/self", "syll.png", "image/png", PDF,
            params(null, typeId(c, "SYLL"), null)).expectOk().id();
        JsonNode mine = api.get(token, "/api/v1/employee-documents/self").expectOk().body();
        assertThat(mine).hasSize(1);
        assertThat(mine.get(0).get("status").asText()).isEqualTo("PENDING");
        // NV tự xem lại bản của mình được
        assertThat(api.rawGet(api.get(token, "/api/v1/employee-documents/self/" + id + "/link").expectOk().text("url"))
            .getKey()).isEqualTo(200);

        assertThat(api.get(c.adminToken, "/api/v1/employee-documents/pending").expectOk().body()).hasSize(1);
        JsonNode missing = api.get(c.adminToken, "/api/v1/employee-documents/missing").expectOk().body();
        assertThat(missingTypesOf(missing, e.id())).hasSize(2);

        api.post(c.adminToken, "/api/v1/employee-documents/" + id + "/approve", Map.of("note", "ok")).expectOk();
        assertThat(api.get(c.adminToken, "/api/v1/employee-documents/pending").expectOk().body()).isEmpty();
        missing = api.get(c.adminToken, "/api/v1/employee-documents/missing").expectOk().body();
        assertThat(missingTypesOf(missing, e.id())).hasSize(1);
        // Đã duyệt thì NV không rút được nữa; duyệt lại → not_pending
        assertThat(api.delete(token, "/api/v1/employee-documents/self/" + id).raw()).contains("error.document.not_pending");
        assertThat(api.post(c.adminToken, "/api/v1/employee-documents/" + id + "/reject", Map.of()).raw())
            .contains("error.document.not_pending");

        // HR có quyền nhưng tự gửi bản của mình → không tự duyệt
        c.createRole("HR tài liệu", List.of("EMPLOYEE_VIEW", "EMPLOYEE_DOCUMENT_VIEW", "EMPLOYEE_DOCUMENT_EDIT"));
        var hr = c.emp(2);
        c.setRole(hr, "HR tài liệu");
        String hrToken = c.tokenOf(hr);
        long own = api.uploadWith(hrToken, "/api/v1/employee-documents/self", "cv.pdf", "application/pdf", PDF,
            params(null, typeId(c, "SYLL"), null)).expectOk().id();
        assertThat(api.post(hrToken, "/api/v1/employee-documents/" + own + "/approve", Map.of()).raw())
            .contains("error.document.cannot_review_own");
    }

    private static JsonNode missingTypesOf(JsonNode missing, long employeeId) {
        for (JsonNode m : missing) {
            if (m.get("employeeId").asLong() == employeeId) return m.get("missingTypes");
        }
        throw new IllegalStateException("không có NV " + employeeId);
    }
}
