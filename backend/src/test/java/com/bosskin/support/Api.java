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
        return call(method, token, url, body, java.util.Map.of());
    }

    /** Gọi API kèm header tuỳ ý (vd. X-Device-ID). */
    public Res call(HttpMethod method, String token, String url, Object body, java.util.Map<String, String> headers) {
        try {
            MockHttpServletRequestBuilder req = request(method, url).accept(MediaType.APPLICATION_JSON);
            if (token != null) req.header("Authorization", "Bearer " + token);
            headers.forEach(req::header);
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

    /** Tải file (xuất Excel) — trả nguyên byte. */
    public byte[] download(String token, String url) {
        return download(token, url, null);
    }

    /** Tải file với ngôn ngữ (Accept-Language, vd. "vi") — đầu cột / tên sheet xuất theo ngôn ngữ đó. */
    public byte[] download(String token, String url, String lang) {
        try {
            MockHttpServletRequestBuilder req = request(HttpMethod.GET, url);
            if (token != null) req.header("Authorization", "Bearer " + token);
            if (lang != null) req.header("Accept-Language", lang);
            MockHttpServletResponse r = mvc.perform(req).andReturn().getResponse();
            if (r.getStatus() != 200) throw new IllegalStateException("GET " + url + " → " + r.getStatus());
            return r.getContentAsByteArray();
        } catch (Exception e) {
            throw new IllegalStateException("DOWNLOAD " + url + " lỗi: " + e.getMessage(), e);
        }
    }

    /** Như {@link #download} nhưng gọi POST (vd. xuất mật khẩu tạm). */
    public byte[] downloadPost(String token, String url) {
        try {
            MockHttpServletRequestBuilder req = request(HttpMethod.POST, url);
            if (token != null) req.header("Authorization", "Bearer " + token);
            MockHttpServletResponse r = mvc.perform(req).andReturn().getResponse();
            if (r.getStatus() != 200) throw new IllegalStateException("POST " + url + " → " + r.getStatus() + " " + r.getContentAsString());
            return r.getContentAsByteArray();
        } catch (Exception e) {
            throw new IllegalStateException("DOWNLOAD " + url + " lỗi: " + e.getMessage(), e);
        }
    }

    /** Gửi file multipart (field "file") — dùng cho /preview-import, /import. */
    public Res upload(String token, String url, String filename, byte[] bytes) {
        try {
            var req = org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart(url)
                .file(new org.springframework.mock.web.MockMultipartFile("file", filename,
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", bytes))
                .accept(MediaType.APPLICATION_JSON);
            if (token != null) req.header("Authorization", "Bearer " + token);
            MockHttpServletResponse r = mvc.perform(req).andReturn().getResponse();
            String raw = r.getContentAsString(StandardCharsets.UTF_8);
            return new Res(r.getStatus(), raw.isBlank() ? json.nullNode() : safeParse(raw), raw);
        } catch (Exception e) {
            throw new IllegalStateException("UPLOAD " + url + " lỗi: " + e.getMessage(), e);
        }
    }

    /** Gửi file multipart (field "file") kèm kiểu nội dung và tham số form — dùng cho tải tài liệu. */
    public Res uploadWith(String token, String url, String filename, String contentType, byte[] bytes,
                          java.util.Map<String, String> params) {
        try {
            var req = org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart(url)
                .file(new org.springframework.mock.web.MockMultipartFile("file", filename, contentType, bytes))
                .accept(MediaType.APPLICATION_JSON);
            params.forEach(req::param);
            if (token != null) req.header("Authorization", "Bearer " + token);
            MockHttpServletResponse r = mvc.perform(req).andReturn().getResponse();
            String raw = r.getContentAsString(StandardCharsets.UTF_8);
            return new Res(r.getStatus(), raw.isBlank() ? json.nullNode() : safeParse(raw), raw);
        } catch (Exception e) {
            throw new IllegalStateException("UPLOAD " + url + " lỗi: " + e.getMessage(), e);
        }
    }

    /** GET không đăng nhập, trả mã trạng thái + byte (link tải ký tạm). */
    public java.util.Map.Entry<Integer, byte[]> rawGet(String url) {
        try {
            MockHttpServletResponse r = mvc.perform(request(HttpMethod.GET, url)).andReturn().getResponse();
            return java.util.Map.entry(r.getStatus(), r.getContentAsByteArray());
        } catch (Exception e) {
            throw new IllegalStateException("GET " + url + " lỗi: " + e.getMessage(), e);
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
