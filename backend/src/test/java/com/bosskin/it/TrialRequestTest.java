package com.bosskin.it;

import com.bosskin.audit.AuditLogRepository;
import com.bosskin.repository.TrialRequestRepository;
import com.bosskin.service.TrialRequestService;
import com.bosskin.support.IntegrationTest;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ThreadLocalRandom;

import static org.assertj.core.api.Assertions.assertThat;

/** Yêu cầu dùng thử từ trang giới thiệu (V12). */
class TrialRequestTest extends IntegrationTest {

    @Autowired TrialRequestService service;
    @Autowired TrialRequestRepository repository;
    @Autowired AuditLogRepository auditLogRepository;

    private static final String URL = "/api/v1/public/trial-requests";

    @BeforeEach @AfterEach
    void resetLimiter() {
        ReflectionTestUtils.setField(service, "maxPerIpHour", 1000);
        ((Map<?, ?>) ReflectionTestUtils.getField(service, "byIp")).clear();
    }

    private String sysToken() {
        return api.post(null, "/admin/auth/login", Map.of("email", "sysadmin@test.local", "password", "Test-SysAdmin-123"))
            .expectOk().text("accessToken");
    }

    private Map<String, Object> form(String phone) {
        Map<String, Object> m = new HashMap<>(Map.of("fullName", "Nguyễn Văn A", "companyName", "Công ty Thử " + phone,
            "phone", phone, "email", "a@example.com", "companySize", "20 – 100", "need", "Chấm công 2 ca", "consent", true));
        return m;
    }

    private String phone() { return "09" + ThreadLocalRandom.current().nextInt(10_000_000, 99_999_999); }

    @Test
    @DisplayName("Khách gửi form không cần đăng nhập; system admin thấy, đổi trạng thái (ghi nhật ký) và xuất Excel; người dùng công ty không xem được")
    void submit_list_update_export() {
        String p = phone();
        assertThat(api.post(null, URL, form(p)).status()).isEqualTo(201);
        var saved = repository.findAll().stream().filter(t -> t.getPhone().equals(p)).findFirst().orElseThrow();
        assertThat(saved.getStatus().name()).isEqualTo("NEW");

        String sys = sysToken();
        var list = api.get(sys, "/admin/trial-requests?status=NEW&q=" + p).expectOk().body();
        assertThat(list.path("content")).hasSize(1);
        assertThat(api.get(sys, "/admin/trial-requests/count-new").expectOk().body().path("count").asLong()).isGreaterThanOrEqualTo(1);

        var upd = api.patch(sys, "/admin/trial-requests/" + saved.getId(), Map.of("status", "CONTACTED", "adminNote", "Đã gọi, hẹn demo"))
            .expectOk().body();
        assertThat(upd.path("status").asText()).isEqualTo("CONTACTED");
        assertThat(upd.path("handledBy").asText()).isEqualTo("sysadmin@test.local");
        assertThat(auditLogRepository.findAll()).anyMatch(a -> "TRIAL_REQUEST_UPDATE".equals(a.getAction())
            && String.valueOf(saved.getId()).equals(a.getEntityId()));

        var xlsx = api.get(sys, "/admin/trial-requests/export");
        assertThat(xlsx.status()).isEqualTo(200);

        var c = fixture.standardCompany();
        assertThat(api.get(c.adminToken, "/admin/trial-requests").status()).isIn(401, 403);
    }

    @Test
    @DisplayName("Kiểm tra dữ liệu: thiếu đồng ý liên hệ, số điện thoại sai, email sai đều bị từ chối")
    void validation() {
        var f = form(phone()); f.put("consent", false);
        var r = api.post(null, URL, f);
        assertThat(r.status()).isEqualTo(400); assertThat(r.raw()).contains("error.trial.consent_required");
        f = form("12ab"); r = api.post(null, URL, f);
        assertThat(r.raw()).contains("error.trial.phone_invalid");
        f = form(phone()); f.put("email", "khong-phai-email"); r = api.post(null, URL, f);
        assertThat(r.raw()).contains("error.trial.email_invalid");
        f = form(phone()); f.remove("companyName"); r = api.post(null, URL, f);
        assertThat(r.raw()).contains("error.trial.company_required");
    }

    @Test
    @DisplayName("Chống spam: ô bẫy bot và gửi trùng số điện thoại trong 10 phút không lưu; quá số lần theo IP bị chặn 429")
    void antiSpam() {
        String p1 = phone();
        var bot = form(p1); bot.put("website", "http://spam.example");
        assertThat(api.post(null, URL, bot).status()).isEqualTo(201);
        assertThat(repository.findAll()).noneMatch(t -> t.getPhone().equals(p1));

        String p2 = phone();
        api.post(null, URL, form(p2)).expectOk();
        api.post(null, URL, form(p2)).expectOk();
        assertThat(repository.findAll().stream().filter(t -> t.getPhone().equals(p2)).count()).isEqualTo(1);

        ReflectionTestUtils.setField(service, "maxPerIpHour", 2);
        ((Map<?, ?>) ReflectionTestUtils.getField(service, "byIp")).clear();
        api.post(null, URL, form(phone())).expectOk();
        api.post(null, URL, form(phone())).expectOk();
        var blocked = api.post(null, URL, form(phone()));
        assertThat(blocked.status()).isEqualTo(429);
        assertThat(blocked.raw()).contains("error.trial.too_many");
    }
}
