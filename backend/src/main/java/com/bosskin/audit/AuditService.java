package com.bosskin.audit;

import com.bosskin.config.RequestIdFilter;
import com.bosskin.entity.SystemAdmin;
import com.bosskin.entity.User;
import com.bosskin.security.SysAdminImpersonateUser;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Bước 2 — ghi nhật ký thao tác nhạy cảm: sửa/duyệt công, lương, phân quyền, impersonate, khoá kỳ…
 * Ghi trong cùng transaction với thao tác: thao tác rollback thì dòng nhật ký cũng không còn.
 * Người thực hiện, IP và mã request lấy từ ngữ cảnh request hiện tại.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuditService {

    private final AuditLogRepository repo;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    /** Bắt đầu một dòng nhật ký: {@code audit.log("PAYROLL_APPROVE").entity("PAYROLL", id).summary(...).save()}. */
    public Entry log(String action) {
        return new Entry(action);
    }

    /** Gom các cặp key/value thành map giữ thứ tự (dùng cho detail). */
    public static Map<String, Object> map(Object... kv) {
        Map<String, Object> m = new LinkedHashMap<>();
        for (int i = 0; i + 1 < kv.length; i += 2) m.put(String.valueOf(kv[i]), kv[i + 1]);
        return m;
    }

    public final class Entry {
        private final String action;
        private String entityType;
        private String entityId;
        private String summary;
        private Object detail;
        private Long companyId;

        private Entry(String action) { this.action = action; }

        public Entry entity(String type, Object id) {
            this.entityType = type;
            this.entityId = id == null ? null : String.valueOf(id);
            return this;
        }
        public Entry summary(String s) {
            this.summary = s != null && s.length() > 500 ? s.substring(0, 497) + "..." : s;
            return this;
        }
        public Entry detail(Object d) { this.detail = d; return this; }
        /** Công ty của dữ liệu bị tác động (mặc định: công ty của người thực hiện). */
        public Entry company(Long id) { this.companyId = id; return this; }

        public void save() {
            AuditLog.AuditLogBuilder b = AuditLog.builder()
                .action(action).entityType(entityType).entityId(entityId).summary(summary)
                .createdAt(LocalDateTime.now(clock))
                .requestId(RequestIdFilter.current())
                .ip(clientIp());
            Long actorCompany = fillActor(b);
            b.companyId(companyId != null ? companyId : actorCompany);
            if (detail != null) {
                try {
                    b.detail(detail instanceof String s ? s : objectMapper.writeValueAsString(detail));
                } catch (Exception e) {
                    b.detail(String.valueOf(detail));
                }
            }
            repo.save(b.build());
        }
    }

    private static Long fillActor(AuditLog.AuditLogBuilder b) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        Object p = auth != null ? auth.getPrincipal() : null;
        if (p instanceof SysAdminImpersonateUser imp) {
            b.actorType(AuditLog.ActorType.IMPERSONATE).actorEmail(imp.getEmail());
            return imp.getCompanyId();
        }
        if (p instanceof User u) {
            b.actorType(AuditLog.ActorType.USER).actorUserId(u.getId()).actorEmail(u.getEmail());
            return u.getCompanyId();
        }
        if (p instanceof SystemAdmin a) {
            b.actorType(AuditLog.ActorType.SYSTEM_ADMIN).actorUserId(a.getId()).actorEmail(a.getEmail());
            return null;
        }
        b.actorType(AuditLog.ActorType.SYSTEM);
        return null;
    }

    private static String clientIp() {
        if (!(RequestContextHolder.getRequestAttributes() instanceof ServletRequestAttributes attrs)) return null;
        HttpServletRequest req = attrs.getRequest();
        String fwd = req.getHeader("X-Forwarded-For");
        String ip = fwd != null && !fwd.isBlank() ? fwd.split(",")[0].trim() : req.getRemoteAddr();
        return ip != null && ip.length() > 64 ? ip.substring(0, 64) : ip;
    }
}
