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

    /** Mã tài khoản đang giữ token (V33: bảng fcm_tokens, một token thuộc một tài khoản). */
    private java.util.List<Long> ownersOf(String fcmToken) {
        return jdbc.queryForList("SELECT user_id FROM fcm_tokens WHERE token = ?", Long.class, fcmToken);
    }

    private long deviceCount(Fixture.Emp e) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM fcm_tokens WHERE user_id = ?", Long.class, e.userId());
    }

    @Test
    @DisplayName("Máy dùng chung: người sau bật thông báo thì người trước không còn nhận trên máy đó")
    void sameDevice_movesToLatestAccount() {
        var c = fixture.standardCompany();
        var a = c.emp(6);
        var b = c.emp(7);

        enable(c.tokenOf(a));
        enable(c.tokenOf(b));

        assertThat(ownersOf(DEVICE)).containsExactly(b.userId());
    }

    @Test
    @DisplayName("Một tài khoản có nhiều thiết bị: thêm máy thứ hai không làm mất máy thứ nhất")
    void sameAccount_keepsAllDevices() {
        var c = fixture.standardCompany();
        var a = c.emp(6);
        api.patch(c.tokenOf(a), "/api/v1/profile/notification-settings", Map.of(
            "fcmToken", "fcm-device-A-0000000000000000001", "shiftReminderMinutes", 30)).expectOk();
        api.patch(c.tokenOf(a), "/api/v1/profile/notification-settings", Map.of(
            "fcmToken", "fcm-device-B-0000000000000000002", "shiftReminderMinutes", 30)).expectOk();

        assertThat(deviceCount(a)).isEqualTo(2);
        var s = api.get(c.tokenOf(a), "/api/v1/profile/notification-settings").expectOk();
        assertThat(s.body().get("deviceCount").asInt()).isEqualTo(2);
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

        assertThat(ownersOf(DEVICE)).isEmpty();
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
