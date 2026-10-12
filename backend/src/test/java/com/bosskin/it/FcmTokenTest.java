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
    @Autowired org.springframework.jdbc.core.JdbcTemplate jdbc;

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
    @DisplayName("Token bị gỡ (máy dùng chung / đăng xuất / FCM báo hết hạn) thì cài đặt nhắc ca vẫn giữ là bật")
    void tokenCleared_keepsReminderSettings() {
        var c = fixture.standardCompany();
        var a = c.emp(6);
        var b = c.emp(7);
        enable(c.tokenOf(a));
        enable(c.tokenOf(b)); // gỡ token khỏi a

        var res = api.get(c.tokenOf(a), "/api/v1/profile/notification-settings").expectOk().body();
        assertThat(res.path("enabled").asBoolean()).isTrue();
        assertThat(res.path("deviceRegistered").asBoolean()).isFalse();
        assertThat(res.path("shiftReminderMinutes").asInt()).isEqualTo(30);
        assertThat(res.path("checkInOutNotifMinutes").asInt()).isEqualTo(5);
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
    @DisplayName("Xoá phân ca rồi xếp lại giờ khác (dùng lại dòng cũ) → xoá dấu đã nhắc để nhắc lại theo giờ mới")
    void reassignAfterDelete_resetsReminderFlags() {
        var c = fixture.standardCompany();
        var e = c.emp(6);
        long id = api.post(c.adminToken, "/api/v1/shifts/assignments", Map.of(
            "employeeId", e.id(), "workDate", "2026-11-03",
            "customStartTime", "08:00", "customEndTime", "12:00")).expectOk().body().get("id").asLong();
        jdbc.update("UPDATE shift_assignments SET reminder_sent_at = NOW(), check_in_notif_sent_at = NOW(), "
            + "check_out_notif_sent_at = NOW() WHERE id = ?", id);

        assertThat(api.delete(c.adminToken, "/api/v1/shifts/assignments/" + id).status()).isIn(200, 204);
        long again = api.post(c.adminToken, "/api/v1/shifts/assignments", Map.of(
            "employeeId", e.id(), "workDate", "2026-11-03",
            "customStartTime", "13:00", "customEndTime", "17:00")).expectOk().body().get("id").asLong();

        assertThat(again).as("dùng lại dòng phân ca cũ").isEqualTo(id);
        Long stillMarked = jdbc.queryForObject("SELECT COUNT(*) FROM shift_assignments WHERE id = ? AND "
            + "(reminder_sent_at IS NOT NULL OR check_in_notif_sent_at IS NOT NULL OR check_out_notif_sent_at IS NOT NULL)",
            Long.class, id);
        assertThat(stillMarked).isZero();
    }

    @Test
    @DisplayName("Gửi thông báo thử phải đăng nhập")
    void testNotification_requiresLogin() {
        assertThat(api.post(null, "/api/v1/profile/notification-settings/test", Map.of()).status()).isIn(401, 403);
    }
}
