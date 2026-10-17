package com.bosskin.it;

import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** V33 · Hộp thư thông báo lưu ở máy chủ (dùng chung mọi thiết bị) + cài đặt báo đi trễ / về sớm của quản lý. */
class NotificationInboxTest extends IntegrationTest {

    @Autowired org.springframework.jdbc.core.JdbcTemplate jdbc;

    private long add(long userId, String title) {
        jdbc.update("INSERT INTO user_notifications (user_id, type, title, body, created_at) VALUES (?, 'TEST', ?, 'b', NOW(6))", userId, title);
        return jdbc.queryForObject("SELECT MAX(id) FROM user_notifications WHERE user_id = ?", Long.class, userId);
    }

    @Test
    @DisplayName("Danh sách, đếm chưa đọc, đánh dấu đã đọc, xoá — chỉ thấy thông báo của chính mình")
    void inbox_flow_and_isolation() {
        var c = fixture.standardCompany();
        var a = c.emp(6);
        var b = c.emp(7);
        long n1 = add(a.userId(), "một");
        add(a.userId(), "hai");
        add(b.userId(), "của người khác");

        var list = api.get(c.tokenOf(a), "/api/v1/notifications").expectOk();
        assertThat(list.body().size()).isEqualTo(2);
        assertThat(list.body().get(0).get("title").asText()).isEqualTo("hai");   // mới nhất trước
        assertThat(api.get(c.tokenOf(a), "/api/v1/notifications/unread-count").expectOk().body().get("count").asInt()).isEqualTo(2);

        assertThat(api.post(c.tokenOf(a), "/api/v1/notifications/" + n1 + "/read", Map.of()).status()).isEqualTo(204);
        assertThat(api.get(c.tokenOf(a), "/api/v1/notifications/unread-count").expectOk().body().get("count").asInt()).isEqualTo(1);

        // đánh dấu / xoá thông báo của người khác → 404 / bỏ qua, không đụng tới dữ liệu của họ
        assertThat(api.post(c.tokenOf(b), "/api/v1/notifications/" + n1 + "/read", Map.of()).status()).isEqualTo(404);
        api.delete(c.tokenOf(b), "/api/v1/notifications/" + n1);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM user_notifications WHERE id = ?", Long.class, n1)).isEqualTo(1L);

        assertThat(api.post(c.tokenOf(a), "/api/v1/notifications/read-all", Map.of()).status()).isEqualTo(204);
        assertThat(api.get(c.tokenOf(a), "/api/v1/notifications/unread-count").expectOk().body().get("count").asInt()).isZero();
        api.delete(c.tokenOf(a), "/api/v1/notifications");
        assertThat(api.get(c.tokenOf(a), "/api/v1/notifications").expectOk().body().size()).isZero();
        assertThat(api.get(c.tokenOf(b), "/api/v1/notifications").expectOk().body().size()).isEqualTo(1);
    }

    @Test
    @DisplayName("Phải đăng nhập mới đọc được hộp thư")
    void inbox_requiresLogin() {
        assertThat(api.get(null, "/api/v1/notifications").status()).isIn(401, 403);
    }

    @Test
    @DisplayName("Cài đặt báo đi trễ / về sớm lưu theo tài khoản; chỉ người có nhân viên quản lý trực tiếp mới có manager=true")
    void alertSettings_saved_and_managerFlag() {
        var c = fixture.standardCompany();
        var mgr = c.emp(6);
        var emp = c.emp(7);
        assertThat(api.get(c.tokenOf(mgr), "/api/v1/profile/notification-settings").expectOk().body().get("manager").asBoolean()).isFalse();

        jdbc.update("UPDATE employees SET manager_id = ? WHERE id = ?", mgr.id(), emp.id());
        api.patch(c.tokenOf(mgr), "/api/v1/profile/notification-settings", Map.of("lateAlert", true, "earlyLeaveAlert", false)).expectOk();

        var s = api.get(c.tokenOf(mgr), "/api/v1/profile/notification-settings").expectOk().body();
        assertThat(s.get("manager").asBoolean()).isTrue();
        assertThat(s.get("lateAlert").asBoolean()).isTrue();
        assertThat(s.get("earlyLeaveAlert").asBoolean()).isFalse();
    }
}
