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

    private SecretKey key() {
        return Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

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
        return buildToken(claims, email, expiration);
    }

    // ── System admin token ──────────────────────────────────────────────
    public String generateSystemToken(SystemAdmin admin) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("type", TYPE_SYSTEM);
        return buildToken(claims, admin.getEmail(), expiration);
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
        return extractClaim(token, Claims::getExpiration).before(new Date());
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
