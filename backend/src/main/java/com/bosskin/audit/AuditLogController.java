package com.bosskin.audit;

import com.bosskin.entity.User;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.LocalDateTime;

/** Bước 2 — xem nhật ký thao tác. Công ty: quyền AUDIT_VIEW, chỉ dữ liệu công ty mình. System admin: mọi công ty. */
@RestController
@RequiredArgsConstructor
public class AuditLogController {

    private final AuditLogRepository repo;

    public record AuditLogResponse(Long id, Long companyId, String actorEmail, String actorType, String action,
                                   String entityType, String entityId, String summary, String detail,
                                   String ip, String requestId, LocalDateTime createdAt) {
        static AuditLogResponse of(AuditLog a) {
            return new AuditLogResponse(a.getId(), a.getCompanyId(), a.getActorEmail(), a.getActorType().name(),
                a.getAction(), a.getEntityType(), a.getEntityId(), a.getSummary(), a.getDetail(),
                a.getIp(), a.getRequestId(), a.getCreatedAt());
        }
    }

    @GetMapping("/api/v1/audit-logs")
    public ResponseEntity<Page<AuditLogResponse>> companyLogs(
        @AuthenticationPrincipal User user,
        @RequestParam(required = false) String action,
        @RequestParam(required = false) String entityType,
        @RequestParam(required = false) String entityId,
        @RequestParam(required = false) String actor,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "50") int size
    ) {
        if (user == null || !user.hasPermission("AUDIT_VIEW") || user.getCompanyId() == null) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        return ResponseEntity.ok(search(user.getCompanyId(), action, entityType, entityId, actor, from, to, page, size));
    }

    @GetMapping("/admin/audit-logs")
    public ResponseEntity<Page<AuditLogResponse>> systemLogs(
        @RequestParam(required = false) Long companyId,
        @RequestParam(required = false) String action,
        @RequestParam(required = false) String entityType,
        @RequestParam(required = false) String entityId,
        @RequestParam(required = false) String actor,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "50") int size
    ) {
        return ResponseEntity.ok(search(companyId, action, entityType, entityId, actor, from, to, page, size));
    }

    private Page<AuditLogResponse> search(Long companyId, String action, String entityType, String entityId,
                                          String actor, LocalDate from, LocalDate to, int page, int size) {
        return repo.search(companyId, blank(action), blank(entityType), blank(entityId), blank(actor),
                from != null ? from.atStartOfDay() : null,
                to != null ? to.plusDays(1).atStartOfDay() : null,
                PageRequest.of(Math.max(0, page), Math.min(Math.max(1, size), 200)))
            .map(AuditLogResponse::of);
    }

    private static String blank(String s) { return s == null || s.isBlank() ? null : s.trim(); }
}
