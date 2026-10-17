package com.bosskin.it;

import com.bosskin.support.Api;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** V31: chức vụ chung (không thuộc phòng ban) dùng được ở mọi phòng ban. */
class CommonPositionTest extends IntegrationTest {

    @Autowired Fixture fixture;
    @Autowired Api api;

    @Test
    void commonPositionIsListedForEveryDepartmentAndCodeIsUniquePerCompany() {
        var c = fixture.newCompany();
        long deptA = api.post(c.adminToken, "/api/v1/departments", Map.of("name", "Cua hang A", "code", "CHA")).expectOk().id();
        long deptB = api.post(c.adminToken, "/api/v1/departments", Map.of("name", "Cua hang B", "code", "CHB")).expectOk().id();

        JsonNode common = api.post(c.adminToken, "/api/v1/positions", Map.of("name", "Quan ly", "code", "QLY")).expectOk().body();
        assertThat(common.get("common").asBoolean()).isTrue();
        assertThat(common.get("departmentId").isNull()).isTrue();

        api.post(c.adminToken, "/api/v1/positions", Map.of("name", "Rieng A", "code", "RA", "departmentId", deptA)).expectOk();

        assertThat(codes(api.get(c.adminToken, "/api/v1/positions?departmentId=" + deptA).expectOk().body())).containsExactlyInAnyOrder("QLY", "RA");
        assertThat(codes(api.get(c.adminToken, "/api/v1/positions?departmentId=" + deptB).expectOk().body())).containsExactly("QLY");
        assertThat(api.post(c.adminToken, "/api/v1/positions", Map.of("name", "Trung", "code", "QLY", "departmentId", deptB)).status()).isEqualTo(409);
    }

    private static java.util.List<String> codes(JsonNode arr) {
        var out = new java.util.ArrayList<String>();
        arr.forEach(n -> out.add(n.get("code").asText()));
        return out;
    }
}
