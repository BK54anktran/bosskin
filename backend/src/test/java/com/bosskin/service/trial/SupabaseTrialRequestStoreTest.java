package com.bosskin.service.trial;

import com.bosskin.entity.TrialRequest;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageRequest;
import org.springframework.web.server.ResponseStatusException;

import java.net.InetSocketAddress;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Supabase (PostgREST) giả lập bằng HttpServer: kiểm tra câu truy vấn, header khoá bí mật và chuyển đổi dữ liệu. */
class SupabaseTrialRequestStoreTest {

    HttpServer server;
    final List<String> calls = new ArrayList<>();
    final List<String> keys = new ArrayList<>();
    final List<String> bodies = new ArrayList<>();
    int status = 200; String reply = "[]"; String range = null;
    SupabaseTrialRequestStore store;

    static final String ROW = """
        [{"id":7,"full_name":"Trần Thị Bình","company_name":"Xưởng may Bình Minh","phone":"0912345678","email":null,
          "company_size":"20 – 100","need":"Chấm công 2 ca","consent":true,"status":"NEW","admin_note":null,"source":"x",
          "ip":"1.2.3.4","created_at":"2026-10-09T03:58:43.310194+00:00","handled_by":null,"handled_at":null}]""";

    @BeforeEach
    void start() throws Exception {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", ex -> {
            calls.add(ex.getRequestMethod() + " " + URLDecoder.decode(ex.getRequestURI().getRawQuery() == null ? ex.getRequestURI().getPath()
                : ex.getRequestURI().getPath() + "?" + ex.getRequestURI().getRawQuery(), StandardCharsets.UTF_8));
            keys.add(ex.getRequestHeaders().getFirst("apikey") + "|" + ex.getRequestHeaders().getFirst("Prefer"));
            bodies.add(new String(ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            if (range != null) ex.getResponseHeaders().add("Content-Range", range);
            byte[] b = reply.getBytes(StandardCharsets.UTF_8);
            ex.sendResponseHeaders(status, b.length == 0 ? -1 : b.length);
            if (b.length > 0) ex.getResponseBody().write(b);
            ex.close();
        });
        server.start();
        store = new SupabaseTrialRequestStore("http://127.0.0.1:" + server.getAddress().getPort() + "/", "sb_secret_test", new ObjectMapper());
    }

    @AfterEach void stop() { server.stop(0); }

    @Test
    @DisplayName("Danh sách: lọc trạng thái + tìm kiếm + phân trang, đọc tổng từ Content-Range, đổi giờ UTC sang giờ VN")
    void search() {
        reply = ROW; range = "20-20/57";
        var page = store.search(TrialRequest.Status.NEW, "Bình (x)", PageRequest.of(1, 20));
        assertThat(calls.get(0)).startsWith("GET /rest/v1/trial_requests?select=*&order=created_at.desc,id.desc&offset=20&limit=20&status=eq.NEW")
            .contains("&or=(full_name.ilike.*Bình  x*,company_name.ilike.*Bình  x*");
        assertThat(keys.get(0)).isEqualTo("sb_secret_test|count=exact");
        assertThat(page.getTotalElements()).isEqualTo(57);
        TrialRequest t = page.getContent().get(0);
        assertThat(t.getId()).isEqualTo(7); assertThat(t.getCompanyName()).isEqualTo("Xưởng may Bình Minh");
        assertThat(t.getCreatedAt()).isEqualTo(LocalDateTime.of(2026, 10, 9, 10, 58, 43, 310194000));
        assertThat(t.getEmail()).isNull();
    }

    @Test
    @DisplayName("Đổi trạng thái: PATCH đúng dòng, gửi người/giờ xử lý; đếm yêu cầu mới; thêm mới chỉ gửi cột cho phép")
    void updateCountInsert() {
        reply = ROW.replace("\"NEW\"", "\"CONTACTED\"");
        TrialRequest t = TrialRequest.builder().id(7L).status(TrialRequest.Status.CONTACTED).adminNote("Đã gọi")
            .handledBy("admin@x").handledAt(LocalDateTime.of(2026, 10, 9, 11, 0)).build();
        assertThat(store.saveHandling(t).getStatus()).isEqualTo(TrialRequest.Status.CONTACTED);
        assertThat(calls.get(0)).isEqualTo("PATCH /rest/v1/trial_requests?id=eq.7");
        assertThat(bodies.get(0)).contains("\"status\":\"CONTACTED\"", "\"admin_note\":\"Đã gọi\"", "\"handled_at\":\"2026-10-09T11:00+07:00\"");

        reply = ""; range = "*/3"; status = 200;
        assertThat(store.countNew()).isEqualTo(3);

        status = 201; range = null;
        store.insert(TrialRequest.builder().fullName("A B").companyName("C D").phone("0900000000").source("s").ip("9.9.9.9").build());
        assertThat(bodies.get(2)).contains("\"consent\":true").doesNotContain("ip").doesNotContain("status");
    }

    @Test
    @DisplayName("Lỗi từ trigger chống spam giữ nguyên mã lỗi; lỗi khác báo error.trial.store_unavailable")
    void errors() {
        status = 400; reply = "{\"message\":\"error.trial.phone_invalid\"}";
        assertThatThrownBy(() -> store.insert(TrialRequest.builder().fullName("A").companyName("B").phone("1").build()))
            .isInstanceOf(ResponseStatusException.class).hasMessageContaining("error.trial.phone_invalid");
        status = 401; reply = "{\"message\":\"Invalid API key\"}";
        assertThatThrownBy(() -> store.countNew()).hasMessageContaining("error.trial.store_unavailable");
    }
}
