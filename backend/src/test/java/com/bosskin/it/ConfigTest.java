package com.bosskin.it;

import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MockMvc;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;

/** Hồi quy cho cấu hình sửa ở Mốc 1 (S9 CORS, S13 lộ chi tiết lỗi). */
class ConfigTest extends IntegrationTest {

    @Autowired MockMvc mvc;

    @Test
    @DisplayName("S9 · CORS từ chối origin lạ")
    void s9_corsRejectsUnknownOrigin() throws Exception {
        var res = mvc.perform(options("/api/v1/auth/login")
                .header("Origin", "https://evil.example.com")
                .header("Access-Control-Request-Method", "POST"))
            .andReturn().getResponse();

        assertThat(res.getHeader("Access-Control-Allow-Origin")).isNull();
    }

    @Test
    @DisplayName("S9 · CORS cho phép localhost khi dev (cổng bất kỳ)")
    void s9_corsAllowsLocalhostDev() throws Exception {
        var res = mvc.perform(options("/api/v1/auth/login")
                .header("Origin", "http://localhost:53712")
                .header("Access-Control-Request-Method", "POST"))
            .andReturn().getResponse();

        assertThat(res.getHeader("Access-Control-Allow-Origin")).isEqualTo("http://localhost:53712");
    }

    @Test
    @DisplayName("S13 · Lỗi tham số trả mã lỗi chung, không lộ tên lớp Java")
    void s13_badRequestDoesNotLeakInternals() {
        var c = fixture.newCompany();

        var res = api.get(c.adminToken, "/api/v1/attendances?year=abc&month=1");

        assertThat(res.status()).isEqualTo(400);
        assertThat(res.raw()).doesNotContain("java.").doesNotContain("Exception");
    }
}
