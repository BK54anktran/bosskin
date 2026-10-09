package com.bosskin.service;

import com.bosskin.audit.AuditService;
import com.bosskin.dto.TrialRequestDTO;
import com.bosskin.entity.TrialRequest;
import com.bosskin.service.trial.TrialRequestStore;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Pattern;

/** Yêu cầu dùng thử từ trang giới thiệu: nhận công khai (chống spam), system admin xử lý. Nơi lưu: {@link TrialRequestStore}. */
@Service
@RequiredArgsConstructor
public class TrialRequestService {

    private static final Pattern EMAIL = Pattern.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]{2,}$");
    private static final Pattern PHONE_CHARS = Pattern.compile("^[+0-9 .()-]{9,20}$");
    private static final long WINDOW_SECONDS = 3600;

    private final TrialRequestStore store;
    private final AuditService audit;
    private final Clock clock;
    /** IP → mốc gửi trong 1 giờ gần nhất (bộ nhớ của một instance, như LoginAttemptService). */
    private final Map<String, Deque<Instant>> byIp = new ConcurrentHashMap<>();

    @Value("${app.trial-request.max-per-ip-hour:5}")
    private int maxPerIpHour;

    /** @return true nếu đã lưu; false nếu bỏ qua im lặng (bot / gửi trùng) — client vẫn nhận "đã gửi". */
    @Transactional
    public boolean submit(TrialRequestDTO.SubmitRequest r, String ip) {
        if (r.getWebsite() != null && !r.getWebsite().isBlank()) return false;          // bẫy bot
        String name = trim(r.getFullName(), 100), company = trim(r.getCompanyName(), 150);
        String phone = r.getPhone() == null ? null : r.getPhone().trim();
        String email = trim(r.getEmail(), 150);
        if (name == null || name.length() < 2) throw bad("error.trial.name_required");
        if (company == null || company.length() < 2) throw bad("error.trial.company_required");
        if (phone == null || !PHONE_CHARS.matcher(phone).matches() || digits(phone) < 9 || digits(phone) > 15)
            throw bad("error.trial.phone_invalid");
        if (email != null && !EMAIL.matcher(email).matches()) throw bad("error.trial.email_invalid");
        if (!Boolean.TRUE.equals(r.getConsent())) throw bad("error.trial.consent_required");
        rateLimit(ip);
        String normPhone = phone.replaceAll("[^+0-9]", "");
        if (store.phoneSubmittedAfter(normPhone, LocalDateTime.now(clock).minusMinutes(10))) return false;
        store.insert(TrialRequest.builder().fullName(name).companyName(company).phone(normPhone).email(email)
            .companySize(trim(r.getCompanySize(), 30)).need(trim(r.getNeed(), 1000)).source(trim(r.getSource(), 200))
            .ip(ip).build());
        return true;
    }

    private void rateLimit(String ip) {
        String key = ip == null ? "?" : ip;
        Instant now = clock.instant();
        Deque<Instant> q = byIp.computeIfAbsent(key, k -> new ArrayDeque<>());
        synchronized (q) {
            while (!q.isEmpty() && q.peekFirst().isBefore(now.minusSeconds(WINDOW_SECONDS))) q.pollFirst();
            if (q.size() >= maxPerIpHour) throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS, "error.trial.too_many");
            q.addLast(now);
        }
    }

    @Transactional
    public TrialRequestDTO.Response update(Long id, TrialRequestDTO.UpdateRequest r, String adminEmail) {
        TrialRequest t = store.find(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.trial.not_found"));
        TrialRequest.Status before = t.getStatus();
        if (r.getStatus() != null) t.setStatus(r.getStatus());
        if (r.getAdminNote() != null) t.setAdminNote(trim(r.getAdminNote(), 1000));
        t.setHandledBy(adminEmail);
        t.setHandledAt(LocalDateTime.now(clock));
        t = store.saveHandling(t);
        audit.log("TRIAL_REQUEST_UPDATE").entity("TRIAL_REQUEST", t.getId())
            .summary(t.getCompanyName() + " · " + before + " → " + t.getStatus())
            .detail(AuditService.map("status", t.getStatus(), "note", t.getAdminNote())).save();
        return TrialRequestDTO.Response.of(t);
    }

    private static int digits(String s) { return s.replaceAll("\\D", "").length(); }
    private static String trim(String s, int max) {
        if (s == null) return null;
        String t = s.trim();
        if (t.isEmpty()) return null;
        return t.length() > max ? t.substring(0, max) : t;
    }
    private static ResponseStatusException bad(String key) { return new ResponseStatusException(HttpStatus.BAD_REQUEST, key); }
}
