package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/** Hộp thư thông báo của tài khoản, lưu ở máy chủ nên mọi thiết bị thấy giống nhau (V33). */
@Entity
@Table(name = "user_notifications")
@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class UserNotification {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "type", nullable = false, length = 40)
    private String type;

    @Column(name = "title", nullable = false, length = 200)
    private String title;

    @Column(name = "body", nullable = false, length = 1000)
    private String body;

    /** JSON {khoá: giá trị}; null nếu không có. */
    @Column(name = "data", length = 1000)
    private String data;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @Column(name = "read_at")
    private LocalDateTime readAt;
}
