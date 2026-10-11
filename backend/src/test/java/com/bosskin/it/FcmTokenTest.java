package com.bosskin.it;

import com.bosskin.repository.UserRepository;
import com.bosskin.support.Fixture;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** F10 · Vòng đời FCM token: một thiết bị chỉ nhận thông báo của tài khoản đang dùng nó. */
class FcmTokenTest extends IntegrationTest {

    @Autowired UserRepository userRepository;

    private static final String DEVICE = "fcm-device-token-shared-phone-0001";

    private void enable(String token) {
        api.patch(token, "/api/v1/profile/notification-settings", Map.of(
            "fcmToken", DEVICE, "shiftReminderMinutes", 30, "checkInOutNotifMinutes", 5)).expectOk();
    }

    private String tokenInDb(Fixture.Emp e) {
        return userRepository.findById(e.userId()).orElseThrow().getFcmToken();
    }

    @Test
    @DisplayName("Máy dùng chung: người sau bật thông báo thì người trước không còn nhận trên máy đó")
    void sameDevice_movesToLatestAccount() {
        var c = fixture.standardCompany();
        var a = c.emp(6);
        var b = c.emp(7);

        enable(c.tokenOf(a));
        enable(c.tokenOf(b));

        assertThat(tokenInDb(a)).isNull();
        assertThat(tokenInDb(b)).isEqualTo(DEVICE);
    }

    @Test
    @DisplayName("Đăng xuất gửi kèm FCM token thì backend gỡ token khỏi tài khoản")
    void logoutWithFcmToken_clearsToken() {
        var c = fixture.standardCompany();
        var a = c.emp(6);
        enable(c.tokenOf(a));
        String refresh = api.login(a.email(), Fixture.PASSWORD).expectOk().text("refreshToken");

        assertThat(api.post(null, "/api/v1/auth/logout",
            Map.of("refreshToken", refresh, "fcmToken", DEVICE)).status()).isEqualTo(204);

        assertThat(tokenInDb(a)).isNull();
    }

    @Test
    @DisplayName("Gửi thông báo thử khi máy chủ chưa cấu hình Firebase → 503 kèm mã lỗi rõ ràng")
    void testNotification_firebaseNotConfigured() {
        var c = fixture.standardCompany();
        var a = c.emp(6);
        enable(c.tokenOf(a));

        var res = api.post(c.tokenOf(a), "/api/v1/profile/notification-settings/test",
            Map.of("title", "BossKin", "body", "Thông báo thử"));

        assertThat(res.status()).isEqualTo(503);
        assertThat(res.raw()).contains("error.notification.not_configured");
    }

    @Test
    @DisplayName("Gửi thông báo thử phải đăng nhập")
    void testNotification_requiresLogin() {
        assertThat(api.post(null, "/api/v1/profile/notification-settings/test", Map.of()).status()).isIn(401, 403);
    }
}
