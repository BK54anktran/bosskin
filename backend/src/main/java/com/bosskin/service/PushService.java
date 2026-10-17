package com.bosskin.service;

import com.bosskin.entity.FcmToken;
import com.bosskin.entity.User;
import com.bosskin.entity.UserNotification;
import com.bosskin.repository.FcmTokenRepository;
import com.bosskin.repository.UserNotificationRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Thông báo của tài khoản (V33): ghi MỘT bản vào hộp thư ở máy chủ (đăng nhập máy nào cũng xem được) rồi đẩy tới
 * thiết bị đã đăng ký của tài khoản đó (máy bật thông báo sau cùng).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PushService {

    /** Hộp thư giữ tối đa chừng này ngày. */
    private static final int KEEP_DAYS = 90;

    private final UserNotificationRepository inbox;
    private final FcmTokenRepository tokens;
    private final FcmService fcmService;
    private final ObjectMapper mapper;

    /** Lưu hộp thư + đẩy tới thiết bị của tài khoản. {@code data} có thể null; khoá "type" trong data được thêm tự động. */
    public void notifyUser(User user, String type, String title, String body, Map<String, String> data) {
        record(user.getId(), type, title, body, data);
        Map<String, String> payload = new HashMap<>(data != null ? data : Map.of());
        payload.put("type", type);
        for (String t : tokensOf(user.getId())) fcmService.sendSimple(t, title, body, payload);
    }

    /** Chỉ lưu hộp thư (thông báo nhắc ca đã tự đẩy theo từng thiết bị bằng {@link FcmService}). */
    @Transactional
    public void record(Long userId, String type, String title, String body, Map<String, String> data) {
        String json = null;
        if (data != null && !data.isEmpty()) {
            try { json = mapper.writeValueAsString(data); } catch (JsonProcessingException e) { /* bỏ data */ }
        }
        inbox.save(UserNotification.builder().userId(userId).type(type)
            .title(cut(title, 200)).body(cut(body, 1000)).data(json != null && json.length() <= 1000 ? json : null)
            .createdAt(com.bosskin.core.CompanyZone.now()).build());
    }

    public List<String> tokensOf(Long userId) {
        return tokens.findByUserId(userId).stream().map(FcmToken::getToken).toList();
    }

    /**
     * Đăng ký thiết bị nhận thông báo đẩy: mỗi tài khoản MỘT thiết bị (máy bật sau cùng); token từng thuộc tài khoản khác
     * (máy dùng chung) thì chuyển sang tài khoản này. Hộp thư thì dùng chung — đăng nhập máy nào cũng xem được.
     */
    @Transactional
    public void registerToken(Long userId, String token) {
        LocalDateTime now = com.bosskin.core.CompanyZone.now();
        tokens.findByToken(token).filter(t -> !t.getUserId().equals(userId)).ifPresent(t -> tokens.deleteByToken(token));
        FcmToken mine = tokens.findByUserId(userId).stream().findFirst().orElse(null);
        if (mine == null) {
            tokens.save(FcmToken.builder().userId(userId).token(token).createdAt(now).updatedAt(now).build());
        } else if (!mine.getToken().equals(token)) {
            mine.setToken(token);
            mine.setUpdatedAt(now);
            tokens.save(mine);
        }
    }

    /** Dọn thông báo cũ hơn {@value #KEEP_DAYS} ngày. */
    @Scheduled(cron = "0 20 3 * * *")
    public void purgeOld() {
        int n = inbox.deleteOlderThan(com.bosskin.core.CompanyZone.now().minusDays(KEEP_DAYS));
        if (n > 0) log.info("Đã dọn {} thông báo cũ", n);
    }

    private static String cut(String s, int max) {
        return s == null ? "" : s.length() <= max ? s : s.substring(0, max);
    }
}
