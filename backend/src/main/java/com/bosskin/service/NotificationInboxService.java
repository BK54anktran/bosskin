package com.bosskin.service;

import com.bosskin.dto.NotificationDTO;
import com.bosskin.entity.User;
import com.bosskin.entity.UserNotification;
import com.bosskin.repository.UserNotificationRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

/** Hộp thư thông báo của chính người dùng (V33): mọi thiết bị đọc cùng một danh sách. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class NotificationInboxService {

    private static final int MAX_PAGE = 100;

    private final UserNotificationRepository repo;
    private final ObjectMapper mapper;

    public List<NotificationDTO.Response> list(User user, int limit) {
        int n = Math.max(1, Math.min(limit, MAX_PAGE));
        return repo.findByUserIdOrderByIdDesc(user.getId(), PageRequest.of(0, n)).stream()
            .map(x -> NotificationDTO.Response.from(x, parse(x.getData()))).toList();
    }

    public NotificationDTO.UnreadCount unread(User user) {
        return NotificationDTO.UnreadCount.builder().count(repo.countByUserIdAndReadAtIsNull(user.getId())).build();
    }

    @Transactional
    public void markRead(User user, Long id) {
        UserNotification n = repo.findByIdAndUserId(id, user.getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.notification.not_found"));
        if (n.getReadAt() == null) {
            n.setReadAt(com.bosskin.core.CompanyZone.now());
            repo.save(n);
        }
    }

    @Transactional
    public void markAllRead(User user) {
        repo.markAllRead(user.getId(), com.bosskin.core.CompanyZone.now());
    }

    @Transactional
    public void delete(User user, Long id) {
        repo.findByIdAndUserId(id, user.getId()).ifPresent(repo::delete);
    }

    @Transactional
    public void clear(User user) {
        repo.deleteAllByUser(user.getId());
    }

    private Map<String, String> parse(String json) {
        if (json == null || json.isBlank()) return Map.of();
        try {
            return mapper.readValue(json, new TypeReference<Map<String, String>>() {});
        } catch (Exception e) {
            return Map.of();
        }
    }
}
