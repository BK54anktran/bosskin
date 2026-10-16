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
}
