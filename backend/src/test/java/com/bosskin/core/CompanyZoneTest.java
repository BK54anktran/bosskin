package com.bosskin.core;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

import java.time.ZoneId;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class CompanyZoneTest {

    @AfterEach
    void cleanup() { CompanyZone.clear(); }

    @Test
    void defaultsToVietnamAndFollowsRequestZone() {
        assertThat(CompanyZone.current()).isEqualTo(ZoneId.of("Asia/Ho_Chi_Minh"));
        CompanyZone.set(ZoneId.of("Asia/Tokyo"));
        assertThat(CompanyZone.clock().getZone()).isEqualTo(ZoneId.of("Asia/Tokyo"));
        // Tokyo nhanh hơn Hà Nội 2 giờ: cùng một thời điểm, giờ địa phương lệch đúng 2 tiếng
        long diff = java.time.Duration.between(
            java.time.LocalDateTime.now(java.time.Clock.system(CompanyZone.DEFAULT)), CompanyZone.now()).toMinutes();
        assertThat(diff).isBetween(119L, 121L);
        CompanyZone.clear();
        assertThat(CompanyZone.clock().getZone()).isEqualTo(CompanyZone.DEFAULT);
    }

    @Test
    void normalizeAcceptsIanaAndRejectsGarbage() {
        assertThat(CompanyZone.normalize("Asia/Bangkok")).isEqualTo("Asia/Bangkok");
        assertThat(CompanyZone.normalize(" ")).isEqualTo(CompanyZone.DEFAULT_ID);
        assertThatThrownBy(() -> CompanyZone.normalize("Mars/Olympus"))
            .isInstanceOf(ResponseStatusException.class).hasMessageContaining("error.company.timezone_invalid");
        assertThat(CompanyZone.parseOrDefault("khong-hop-le")).isEqualTo(CompanyZone.DEFAULT);
    }

    @Test
    void utcOffsetOfBangkokIsPlus7() {
        assertThat(CompanyZone.utcOffsetMinutes(ZoneId.of("Asia/Bangkok"))).isEqualTo(420);
        assertThat(CompanyZone.utcOffsetMinutes(ZoneId.of("Asia/Ho_Chi_Minh"))).isEqualTo(420);
    }

    @Test
    void currencyCatalog() {
        assertThat(CompanyCurrency.normalize(null)).isEqualTo("VND");
        assertThat(CompanyCurrency.normalize("usd")).isEqualTo("USD");
        assertThat(CompanyCurrency.catalog().get("USD").decimals()).isEqualTo(2);
        assertThat(CompanyCurrency.catalog().get("VND").decimals()).isZero();
        assertThatThrownBy(() -> CompanyCurrency.normalize("XXX"))
            .isInstanceOf(ResponseStatusException.class).hasMessageContaining("error.company.currency_invalid");
    }
}
