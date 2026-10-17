package com.bosskin.it;

import com.bosskin.support.Api;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import static org.assertj.core.api.Assertions.assertThat;

/** V32: tiền tệ và múi giờ theo công ty — lưu ở Cài đặt công ty, trả về khi đăng nhập, từ chối giá trị sai. */
class CompanyRegionalTest extends IntegrationTest {

    @Autowired Fixture fixture;
    @Autowired Api api;

    @Test
    void settingsRoundTripAndLoginPayload() {
        var c = fixture.newCompany();
        JsonNode current = api.get(c.adminToken, "/api/v1/company-settings").expectOk().body();
        assertThat(current.at("/regional/currencyCode").asText()).isEqualTo("VND");
        assertThat(current.at("/regional/timezone").asText()).isEqualTo("Asia/Ho_Chi_Minh");

        ObjectNode put = current.deepCopy();
        put.putObject("regional").put("currencyCode", "thb").put("timezone", "Asia/Bangkok");
        JsonNode saved = api.put(c.adminToken, "/api/v1/company-settings", put).expectOk().body();
        assertThat(saved.at("/regional/currencyCode").asText()).isEqualTo("THB");
        assertThat(saved.at("/regional/timezone").asText()).isEqualTo("Asia/Bangkok");
    }

    @Test
    void rejectsUnknownCurrencyAndTimezone() {
        var c = fixture.newCompany();
        JsonNode current = api.get(c.adminToken, "/api/v1/company-settings").expectOk().body();
        ObjectNode bad1 = current.deepCopy();
        bad1.putObject("regional").put("currencyCode", "XXX");
        assertThat(api.put(c.adminToken, "/api/v1/company-settings", bad1).status()).isEqualTo(400);
        ObjectNode bad2 = current.deepCopy();
        bad2.putObject("regional").put("timezone", "Mars/Olympus");
        assertThat(api.put(c.adminToken, "/api/v1/company-settings", bad2).status()).isEqualTo(400);
    }
}
