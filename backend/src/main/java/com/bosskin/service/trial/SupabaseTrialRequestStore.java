package com.bosskin.service.trial;

import com.bosskin.config.ClockConfig;
import com.bosskin.entity.TrialRequest;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Đọc/ghi bảng {@code public.trial_requests} trên Supabase qua REST (PostgREST) bằng khoá bí mật (bỏ qua RLS).
 * Cấu trúc bảng: {@code landing/supabase/*.sql}. Khoá bí mật chỉ nằm ở backend (biến môi trường), không bao giờ gửi ra trình duyệt.
 */
@Slf4j
public class SupabaseTrialRequestStore implements TrialRequestStore {

    private static final String TABLE = "/rest/v1/trial_requests";
    private final String baseUrl;
    private final String secretKey;
    private final ObjectMapper json;
    private final HttpClient http;

    public SupabaseTrialRequestStore(String baseUrl, String secretKey, ObjectMapper json) {
        this.baseUrl = baseUrl.replaceAll("/+$", "");
        this.secretKey = secretKey;
        this.json = json;
        this.http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
    }

    @Override public String name() { return "supabase"; }

    @Override
    public void insert(TrialRequest t) {
        ObjectNode b = json.createObjectNode();
        b.put("full_name", t.getFullName()); b.put("company_name", t.getCompanyName()); b.put("phone", t.getPhone());
        b.put("email", t.getEmail()); b.put("company_size", t.getCompanySize()); b.put("need", t.getNeed());
        b.put("consent", true); b.put("source", t.getSource());
        send("POST", TABLE, b.toString(), "return=minimal");
    }

    @Override
    public boolean phoneSubmittedAfter(String phone, LocalDateTime after) {
        String q = "?select=id&limit=1&phone=eq." + enc(phone) + "&created_at=gt." + enc(after.atZone(ClockConfig.ZONE).toOffsetDateTime().toString());
        return send("GET", TABLE + q, null, null).body().size() > 0;
    }

    @Override
    public Page<TrialRequest> search(TrialRequest.Status status, String q, Pageable pageable) {
        StringBuilder qs = new StringBuilder("?select=*&order=created_at.desc,id.desc")
            .append("&offset=").append(pageable.getOffset()).append("&limit=").append(pageable.getPageSize());
        if (status != null) qs.append("&status=eq.").append(status.name());
        if (q != null && !q.isBlank()) {
            String term = q.trim().replaceAll("[,()*\"\\\\]", " ").trim();       // ký tự đặc biệt của bộ lọc PostgREST
            if (!term.isEmpty()) {
                String p = "*" + term + "*";
                qs.append("&or=").append(enc("(full_name.ilike." + p + ",company_name.ilike." + p + ",phone.ilike." + p + ",email.ilike." + p + ")"));
            }
        }
        Res r = send("GET", TABLE + qs, null, "count=exact");
        return new PageImpl<>(rows(r.body()), pageable, r.total());
    }

    @Override
    public List<TrialRequest> findAllForExport(TrialRequest.Status status) {
        String qs = "?select=*&order=created_at.desc,id.desc&limit=10000" + (status != null ? "&status=eq." + status.name() : "");
        return rows(send("GET", TABLE + qs, null, null).body());
    }

    @Override
    public long countNew() {
        return send("GET", TABLE + "?select=id&status=eq.NEW&limit=1", null, "count=exact").total();
    }

    @Override
    public Optional<TrialRequest> find(Long id) {
        return rows(send("GET", TABLE + "?select=*&id=eq." + id, null, null).body()).stream().findFirst();
    }

    @Override
    public TrialRequest saveHandling(TrialRequest t) {
        ObjectNode b = json.createObjectNode();
        b.put("status", t.getStatus().name()); b.put("admin_note", t.getAdminNote()); b.put("handled_by", t.getHandledBy());
        b.put("handled_at", t.getHandledAt() == null ? null : t.getHandledAt().atZone(ClockConfig.ZONE).toOffsetDateTime().toString());
        List<TrialRequest> out = rows(send("PATCH", TABLE + "?id=eq." + t.getId(), b.toString(), "return=representation").body());
        if (out.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "error.trial.not_found");
        return out.get(0);
    }

    // ── HTTP ────────────────────────────────────────────────────────────────
    record Res(JsonNode body, long total) {}

    private Res send(String method, String path, String body, String prefer) {
        HttpRequest.Builder b = HttpRequest.newBuilder(URI.create(baseUrl + path)).timeout(Duration.ofSeconds(20))
            .header("apikey", secretKey).header("Accept", "application/json");
        if (secretKey.startsWith("eyJ")) b.header("Authorization", "Bearer " + secretKey);   // khoá service_role kiểu cũ (JWT)
        if (prefer != null) b.header("Prefer", prefer);
        b.method(method, body == null ? HttpRequest.BodyPublishers.noBody()
            : HttpRequest.BodyPublishers.ofString(body, StandardCharsets.UTF_8));
        if (body != null) b.header("Content-Type", "application/json");
        HttpResponse<String> r;
        try {
            r = http.send(b.build(), HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
        } catch (Exception e) {
            if (e instanceof InterruptedException) Thread.currentThread().interrupt();
            log.warn("Supabase {} {} lỗi kết nối: {}", method, path, e.toString());
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "error.trial.store_unavailable");
        }
        if (r.statusCode() >= 300) {
            String msg = "";
            try { msg = json.readTree(r.body()).path("message").asText(""); } catch (Exception ignored) { }
            if (msg.startsWith("error.trial.")) {                                  // lỗi do trigger chống spam đặt
                throw new ResponseStatusException(msg.equals("error.trial.too_many") ? HttpStatus.TOO_MANY_REQUESTS : HttpStatus.BAD_REQUEST, msg);
            }
            log.warn("Supabase {} {} -> {} {}", method, path, r.statusCode(), r.body());
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "error.trial.store_unavailable");
        }
        long total = -1;
        String range = r.headers().firstValue("Content-Range").orElse("");          // vd "0-19/57" hoặc "*/57"
        int slash = range.lastIndexOf('/');
        if (slash >= 0 && !range.endsWith("*")) total = Long.parseLong(range.substring(slash + 1));
        try {
            JsonNode node = r.body() == null || r.body().isBlank() ? json.createArrayNode() : json.readTree(r.body());
            return new Res(node, total);
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "error.trial.store_unavailable");
        }
    }

    private List<TrialRequest> rows(JsonNode arr) {
        List<TrialRequest> out = new ArrayList<>();
        for (JsonNode n : arr) {
            TrialRequest t = TrialRequest.builder().id(n.path("id").asLong()).fullName(txt(n, "full_name"))
                .companyName(txt(n, "company_name")).phone(txt(n, "phone")).email(txt(n, "email"))
                .companySize(txt(n, "company_size")).need(txt(n, "need"))
                .status(TrialRequest.Status.valueOf(n.path("status").asText("NEW")))
                .adminNote(txt(n, "admin_note")).source(txt(n, "source")).handledBy(txt(n, "handled_by"))
                .handledAt(time(n, "handled_at")).build();
            t.setCreatedAt(time(n, "created_at"));
            out.add(t);
        }
        return out;
    }

    private static String txt(JsonNode n, String f) { JsonNode v = n.get(f); return v == null || v.isNull() ? null : v.asText(); }
    private static LocalDateTime time(JsonNode n, String f) {
        String s = txt(n, f);
        return s == null ? null : OffsetDateTime.parse(s).atZoneSameInstant(ClockConfig.ZONE).toLocalDateTime();
    }
    private static String enc(String s) { return URLEncoder.encode(s, StandardCharsets.UTF_8); }
}
