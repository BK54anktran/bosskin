package com.bosskin.it;

import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class UserLanguageTest extends IntegrationTest {

    @Autowired JdbcTemplate jdbc;

    private String language(long userId) {
        return jdbc.query("SELECT language FROM users WHERE id = ?", rs -> rs.next() ? rs.getString(1) : null, userId);
    }

    @Test
    @DisplayName("Ngôn ngữ app (Accept-Language) được lưu theo người dùng để gửi thông báo đẩy đúng ngôn ngữ; không có header thì không đổi")
    void languageFollowsAcceptLanguage() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        String token = c.tokenOf(e);
        assertThat(language(e.userId())).isNull();

        api.call(org.springframework.http.HttpMethod.GET, token, "/api/v1/profile", null, Map.of("Accept-Language", "en")).expectOk();
        assertThat(language(e.userId())).isEqualTo("en");

        api.get(token, "/api/v1/profile").expectOk();
        assertThat(language(e.userId())).as("không có header → giữ nguyên").isEqualTo("en");

        api.call(org.springframework.http.HttpMethod.GET, token, "/api/v1/profile", null, Map.of("Accept-Language", "fr")).expectOk();
        assertThat(language(e.userId())).as("ngôn ngữ lạ → coi như vi").isEqualTo("vi");
    }

    @Autowired com.bosskin.service.CompanyService companyService;

    private com.bosskin.dto.CreateCompanyRequest request(String code, String language) {
        var req = new com.bosskin.dto.CreateCompanyRequest();
        req.setName("Seed " + code);
        req.setCode(code);
        req.setDomain(code.toLowerCase() + ".test");
        req.setAdminEmail("admin@" + code.toLowerCase() + ".test");
        req.setAdminPassword("Passw0rd!x");
        req.setLanguage(language);
        return req;
    }

    @Test
    @DisplayName("Công ty mới tạo vai trò và loại tài liệu mặc định theo ngôn ngữ chọn (en → tiếng Anh, trống → tiếng Việt); vai trò mặc định tìm theo cờ, không theo tên")
    void companyDefaultsFollowChosenLanguage() {
        long en = companyService.create(request("SEEDEN" + System.nanoTime() % 100000, "en")).getId();
        long vi = companyService.create(request("SEEDVI" + System.nanoTime() % 100000, null)).getId();

        assertThat(jdbc.queryForList("SELECT name FROM roles WHERE company_id = ? AND is_default = 1", String.class, en)).containsExactly("Employee");
        assertThat(jdbc.queryForList("SELECT name FROM document_types WHERE company_id = ? AND code = 'SYLL'", String.class, en)).containsExactly("Curriculum vitae");
        assertThat(jdbc.queryForList("SELECT name FROM roles WHERE company_id = ? AND is_default = 1", String.class, vi)).containsExactly("Nhân viên");
        assertThat(jdbc.queryForList("SELECT name FROM document_types WHERE company_id = ? AND code = 'SYLL'", String.class, vi)).containsExactly("Sơ yếu lý lịch");
    }
}
