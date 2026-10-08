package com.bosskin.i18n;

import jakarta.servlet.http.HttpServletRequest;
import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.ErrorResponse;

@Slf4j
@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String, Object>> handle(ResponseStatusException ex, HttpServletRequest request) {
        final String reason = ex.getReason() != null ? ex.getReason() : ex.getMessage();
        // Backend trả mã lỗi ("error.x.y" hoặc "error.x.y|tham số"); FE dịch theo ngôn ngữ người dùng.
        final String message = reason;
        final HttpStatusCode status = ex.getStatusCode();

        return build(status, message, request);
    }

    /** Trùng khoá unique / vi phạm ràng buộc DB: trả 409 với mã lỗi, không lộ câu SQL. */
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, Object>> handleConflict(DataIntegrityViolationException ex, HttpServletRequest request) {
        log.warn("Vi phạm ràng buộc dữ liệu tại {}: {}", request.getRequestURI(), ex.getMostSpecificCause().getMessage());
        return build(HttpStatus.CONFLICT,
            "error.data.conflict", request);
    }

    /**
     * Mọi lỗi còn lại. Lỗi chuẩn của Spring (400 validate, 404, 405…) giữ đúng mã HTTP;
     * lỗi không lường trước trả 500 với mã chung, chi tiết chỉ ghi log — không lộ ra client.
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleOther(Exception ex, HttpServletRequest request) throws Exception {
        if (ex instanceof AccessDeniedException || ex instanceof AuthenticationException) {
            throw ex; // để Spring Security xử lý 401/403 như cũ
        }
        if (ex instanceof org.springframework.beans.TypeMismatchException
                || ex instanceof org.springframework.http.converter.HttpMessageNotReadableException
                || ex instanceof jakarta.validation.ConstraintViolationException
                || ex instanceof IllegalArgumentException) {
            return build(HttpStatus.BAD_REQUEST,
                "error.bad_request", request);
        }
        if (ex instanceof ErrorResponse er) {
            HttpStatusCode status = er.getStatusCode();
            String key = status.value() == 404 ? "error.not_found" : "error.bad_request";
            return build(status, key, request);
        }
        log.error("Lỗi không xử lý tại {} {}", request.getMethod(), request.getRequestURI(), ex);
        return build(HttpStatus.INTERNAL_SERVER_ERROR,
            "error.internal", request);
    }

    private ResponseEntity<Map<String, Object>> build(HttpStatusCode status, String message, HttpServletRequest request) {
        final Map<String, Object> body = new LinkedHashMap<>();
        body.put("timestamp", OffsetDateTime.now().toString());
        body.put("status", status.value());
        body.put("error", HttpStatus.valueOf(status.value()).getReasonPhrase());
        body.put("message", message);
        body.put("path", request.getRequestURI());
        return ResponseEntity.status(status).body(body);
    }
}
