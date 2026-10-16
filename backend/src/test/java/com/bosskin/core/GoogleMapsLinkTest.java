package com.bosskin.core;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/** Đọc toạ độ từ link Google Maps và danh sách miền được phép theo link rút gọn (chống SSRF). */
class GoogleMapsLinkTest {

    private static final String LONG = "https://www.google.com/maps/place/MAMA+COOK/@10.8522074,106.6232696,138m/data=!3m1!1e3!4m6!3m5!1s0x31752b0024a2f7dd:0xcd0b6b6413f5ee3d!8m2!3d10.8522385!4d106.6237611!16s%2Fg%2F11lmqb322l?entry=tts";

    @Test
    @DisplayName("Link dài: ưu tiên ghim !3d!4d hơn tâm bản đồ @")
    void pinBeatsCenter() {
        var p = GoogleMapsLink.parse(LONG).orElseThrow();
        assertThat(p[0]).isEqualTo(10.8522385);
        assertThat(p[1]).isEqualTo(106.6237611);
    }

    @Test
    @DisplayName("Chỉ có @lat,lng → dùng tâm bản đồ")
    void atOnly() {
        var p = GoogleMapsLink.parse("https://www.google.com/maps/@10.7769,106.7009,15z").orElseThrow();
        assertThat(p).containsExactly(10.7769, 106.7009);
    }

    @Test
    @DisplayName("?q= / ?ll= và chuỗi 'lat, lng' trơn (kể cả dấu cách, toạ độ âm)")
    void queryAndPlain() {
        assertThat(GoogleMapsLink.parse("https://maps.google.com/?q=10.77,106.70").orElseThrow()).containsExactly(10.77, 106.70);
        assertThat(GoogleMapsLink.parse("https://maps.google.com/?q=10.77%2C106.70&z=15").orElseThrow()).containsExactly(10.77, 106.70);
        assertThat(GoogleMapsLink.parse("https://www.google.com/maps?ll=-33.86,151.21").orElseThrow()).containsExactly(-33.86, 151.21);
        assertThat(GoogleMapsLink.parse(" 10.852238, 106.623761 ").orElseThrow()).containsExactly(10.852238, 106.623761);
    }

    @Test
    @DisplayName("Ngoài phạm vi / không có toạ độ → rỗng")
    void invalid() {
        assertThat(GoogleMapsLink.parse("95.0, 106.0")).isEmpty();
        assertThat(GoogleMapsLink.parse("10.0, 200.0")).isEmpty();
        assertThat(GoogleMapsLink.parse("https://maps.app.goo.gl/tk52Nipa8yXuwh1b8")).isEmpty();
        assertThat(GoogleMapsLink.parse("xin chào")).isEmpty();
        assertThat(GoogleMapsLink.parse("")).isEmpty();
        assertThat(GoogleMapsLink.parse(null)).isEmpty();
    }

    @Test
    @DisplayName("Chỉ cho theo link tới các miền Google Maps")
    void allowedHosts() {
        assertThat(GoogleMapsLink.isAllowedHost("maps.app.goo.gl")).isTrue();
        assertThat(GoogleMapsLink.isAllowedHost("www.google.com")).isTrue();
        assertThat(GoogleMapsLink.isAllowedHost("www.google.com.vn")).isTrue();
        assertThat(GoogleMapsLink.isAllowedHost("maps.google.com")).isTrue();
        assertThat(GoogleMapsLink.isAllowedHost("evil.com")).isFalse();
        assertThat(GoogleMapsLink.isAllowedHost("maps.app.goo.gl.evil.com")).isFalse();
        assertThat(GoogleMapsLink.isAllowedHost("169.254.169.254")).isFalse();
        assertThat(GoogleMapsLink.isAllowedHost("localhost")).isFalse();
        assertThat(GoogleMapsLink.isAllowedHost(null)).isFalse();
        assertThat(GoogleMapsLink.isShortLink("https://maps.app.goo.gl/abc")).isTrue();
        assertThat(GoogleMapsLink.isShortLink("https://www.google.com/maps/@1,2,3z")).isFalse();
    }
}
