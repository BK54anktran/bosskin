package com.bosskin.support;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.boot.test.context.TestComponent;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.nio.charset.StandardCharsets;
import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.request;

/**
 * Gọi REST API trong test qua MockMvc (đi qua toàn bộ filter bảo mật thật).
 * Mọi hàm trả {@link Res} gồm status + body JSON, test tự assert.
 */
@TestComponent
public class Api {

    private final MockMvc mvc;
    private final ObjectMapper json;

    public Api(MockMvc mvc, ObjectMapper json) {
        this.mvc = mvc;
        this.json = json;
    }

    public record Res(int status, JsonNode body, String raw) {
        public boolean ok() { return status >= 200 && status < 300; }

        /** Ném lỗi kèm body nếu status không phải 2xx — dùng khi dựng dữ liệu. */
        public Res expectOk() {
            if (!ok()) throw new AssertionError("HTTP " + status + ": " + raw);
            return this;
        }

        public long id() { return body.get("id").asLong(); }

        public String text(String field) { return body.path(field).asText(null); }
    }

    public Res get(String token, String url)                 { return call(HttpMethod.GET, token, url, null); }
    public Res post(String token, String url, Object body)   { return call(HttpMethod.POST, token, url, body); }
    public Res put(String token, String url, Object body)    { return call(HttpMethod.PUT, token, url, body); }
    public Res patch(String token, String url, Object body)  { return call(HttpMethod.PATCH, token, url, body); }
    public Res delete(String token, String url)              { return call(HttpMethod.DELETE, token, url, null); }

    /** Đăng nhập tài khoản công ty, trả về toàn bộ response (accessToken, refreshToken, user). */
    public Res login(String email, String password) {
        return post(null, "/api/v1/auth/login", Map.of("email", email, "password", password));
    }

    public String token(String email, String password) {
        return login(email, password).expectOk().text("accessToken");
    }

    public Res call(HttpMethod method, String token, String url, Object body) {
        try {
            MockHttpServletRequestBuilder req = request(method, url).accept(MediaType.APPLICATION_JSON);
            if (token != null) req.header("Authorization", "Bearer " + token);
            if (body != null) {
                req.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsBytes(body));
            }
            MockHttpServletResponse r = mvc.perform(req).andReturn().getResponse();
            String raw = r.getContentAsString(StandardCharsets.UTF_8);
            JsonNode node = raw.isBlank() ? json.nullNode() : safeParse(raw);
            return new Res(r.getStatus(), node, raw);
        } catch (Exception e) {
            throw new IllegalStateException(method + " " + url + " lỗi: " + e.getMessage(), e);
        }
    }

    private JsonNode safeParse(String raw) {
        try {
            return json.readTree(raw);
        } catch (Exception e) {
            return json.getNodeFactory().textNode(raw);
        }
    }
}
