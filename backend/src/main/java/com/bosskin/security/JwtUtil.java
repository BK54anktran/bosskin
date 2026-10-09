package com.bosskin.security;

import com.bosskin.entity.SystemAdmin;
import com.bosskin.entity.User;
import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;

@Component
public class JwtUtil {

    public static final String TYPE_COMPANY = "COMPANY";
    public static final String TYPE_SYSTEM  = "SYSTEM";

    @Value("${app.jwt.secret}")      private String secret;
    @Value("${app.jwt.expiration}")  private long expiration;
    @Value("${app.jwt.refresh-expiration}") private long refreshExpiration;

    /** Secret cũ từng là giá trị mặc định công khai trong application.yml — cấm dùng lại. */
    private static final String LEAKED_DEFAULT_SECRET = "bosskin-super-secret-key-change-in-production-2024";
    private static final int MIN_SECRET_BYTES = 32;

    @jakarta.annotation.PostConstruct
    void validateSecret() {
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException("Thiếu JWT_SECRET. Tạo bằng: openssl rand -base64 48");
        }
        if (secret.getBytes(StandardCharsets.UTF_8).length < MIN_SECRET_BYTES) {
            throw new IllegalStateException("JWT_SECRET phải dài ít nhất " + MIN_SECRET_BYTES + " byte");
        }
        if (LEAKED_DEFAULT_SECRET.equals(secret)) {
            throw new IllegalStateException("JWT_SECRET đang là giá trị mặc định cũ đã công khai, hãy đổi");
        }
    }

    private SecretKey key() {
        return Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    /** Phiên impersonate của system admin sống tối đa 1 giờ. */
    public static final long IMPERSONATE_EXPIRATION_MS = 60 * 60 * 1000L;

    // ── Company user token ──────────────────────────────────────────────
    public String generateToken(User user, String deviceId) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("type",        TYPE_COMPANY);
        claims.put("companyId",   user.getCompany().getId());
        claims.put("permissions", user.getPermissions());
        if (deviceId != null) claims.put("deviceId", deviceId);
        return buildToken(claims, user.getEmail(), expiration);
    }

    public String generateRefreshToken(User user, String deviceId, String jti) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("type",      "REFRESH");
        claims.put("companyId", user.getCompany().getId());
        claims.put("jti",       jti);
        if (deviceId != null) claims.put("deviceId", deviceId);
        return buildToken(claims, user.getEmail(), refreshExpiration);
    }

    public String newJti() { return UUID.randomUUID().toString(); }
    public long getRefreshExpirationMs() { return refreshExpiration; }

    // ── Impersonate: system admin login into a company ──────────────────
    public String generateImpersonateToken(String email, Long companyId, Set<String> permissions) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("type",        TYPE_COMPANY);
        claims.put("companyId",   companyId);
        claims.put("permissions", permissions);
        claims.put("impersonated", true);
        return buildToken(claims, email, IMPERSONATE_EXPIRATION_MS);
    }

    // ── System admin token ──────────────────────────────────────────────
    public String generateSystemToken(SystemAdmin admin) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("type", TYPE_SYSTEM);
        return buildToken(claims, admin.getEmail(), expiration);
    }

    // ── Bước C: phiếu chờ bước 2 (2FA) — 5 phút, không dùng làm access token ──
    public static final String TYPE_2FA = "2FA";
    public static final long CHALLENGE_EXPIRATION_MS = 5 * 60 * 1000L;

    /** {@code account}: COMPANY | SYSTEM; {@code purpose}: VERIFY (nhập mã) | SETUP (cài lần đầu). */
    public String generateChallengeToken(String email, String account, String purpose, String deviceId) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("type", TYPE_2FA);
        claims.put("account", account);
        claims.put("purpose", purpose);
        if (deviceId != null) claims.put("deviceId", deviceId);
        return buildToken(claims, email, CHALLENGE_EXPIRATION_MS);
    }

    /** Đọc phiếu 2FA còn hạn, sai loại/hết hạn → null. */
    public Claims parseChallenge(String token) {
        try {
            Claims c = extractAllClaims(token);
            return TYPE_2FA.equals(c.get("type")) ? c : null;
        } catch (Exception e) {
            return null;
        }
    }

    // ── Extract helpers ─────────────────────────────────────────────────
    public String  extractUsername(String token) {
        return extractClaim(token, Claims::getSubject);
    }

    public String  extractType(String token) {
        return (String) extractAllClaims(token).get("type");
    }

    public Long    extractCompanyId(String token) {
        Object v = extractAllClaims(token).get("companyId");
        return v == null ? null : Long.valueOf(v.toString());
    }

    public String  extractDeviceId(String token) {
        return (String) extractAllClaims(token).get("deviceId");
    }

    public String  extractJti(String token) {
        return (String) extractAllClaims(token).get("jti");
    }

    public boolean isImpersonateToken(String token) {
        Object v = extractAllClaims(token).get("impersonated");
        return Boolean.TRUE.equals(v);
    }


    @SuppressWarnings("unchecked")
    public Set<String> extractPermissions(String token) {
        Object v = extractAllClaims(token).get("permissions");
        if (v instanceof Set) return (Set<String>) v;
        if (v instanceof java.util.Collection<?> col) {
            return col.stream().map(Object::toString).collect(java.util.stream.Collectors.toSet());
        }
        return Set.of();
    }

    public boolean isTokenValid(String token, UserDetails userDetails) {
        return extractUsername(token).equals(userDetails.getUsername())
            && !isTokenExpired(token);
    }

    public boolean isTokenExpired(String token) {
        try {
            return extractClaim(token, Claims::getExpiration).before(new Date());
        } catch (ExpiredJwtException e) {
            return true;
        }
    }

    public Claims extractAllClaimsIgnoreExpiry(String token) {
        try {
            return Jwts.parser().verifyWith(key()).build()
                .parseSignedClaims(token).getPayload();
        } catch (ExpiredJwtException e) {
            return e.getClaims();
        }
    }

    public long getExpiration() { return expiration; }

    // ── Internal ────────────────────────────────────────────────────────
    private String buildToken(Map<String, Object> claims, String subject, long expirationMs) {
        return Jwts.builder()
            .claims(claims)
            .subject(subject)
            .issuedAt(new Date())
            .expiration(new Date(System.currentTimeMillis() + expirationMs))
            .signWith(key())
            .compact();
    }

    public <T> T extractClaim(String token, Function<Claims, T> resolver) {
        return resolver.apply(extractAllClaims(token));
    }

    private Claims extractAllClaims(String token) {
        return Jwts.parser().verifyWith(key()).build()
            .parseSignedClaims(token).getPayload();
    }
}
