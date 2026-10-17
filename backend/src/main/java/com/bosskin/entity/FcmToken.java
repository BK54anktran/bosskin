package com.bosskin.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/** Token FCM của một thiết bị. Một tài khoản có nhiều thiết bị; một token chỉ thuộc một tài khoản (V33). */
@Entity
@Table(name = "fcm_tokens")
@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class FcmToken {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "token", nullable = false, length = 512)
    private String token;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;
}
