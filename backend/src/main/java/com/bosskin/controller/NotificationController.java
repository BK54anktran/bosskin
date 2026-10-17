package com.bosskin.controller;

import com.bosskin.dto.NotificationDTO;
import com.bosskin.entity.User;
import com.bosskin.service.NotificationInboxService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** Hộp thư thông báo của chính người đăng nhập — chỉ đọc / sửa thông báo của mình, không cần quyền riêng. */
@RestController
@RequestMapping("/api/v1/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationInboxService inbox;

    @GetMapping
    public ResponseEntity<List<NotificationDTO.Response>> list(@AuthenticationPrincipal User user,
                                                               @RequestParam(defaultValue = "50") int limit) {
        return ResponseEntity.ok(inbox.list(user, limit));
    }

    @GetMapping("/unread-count")
    public ResponseEntity<NotificationDTO.UnreadCount> unread(@AuthenticationPrincipal User user) {
        return ResponseEntity.ok(inbox.unread(user));
    }

    @PostMapping("/read-all")
    public ResponseEntity<Void> readAll(@AuthenticationPrincipal User user) {
        inbox.markAllRead(user);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/read")
    public ResponseEntity<Void> read(@AuthenticationPrincipal User user, @PathVariable Long id) {
        inbox.markRead(user, id);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal User user, @PathVariable Long id) {
        inbox.delete(user, id);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping
    public ResponseEntity<Void> clear(@AuthenticationPrincipal User user) {
        inbox.clear(user);
        return ResponseEntity.noContent().build();
    }
}
