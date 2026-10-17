package com.bosskin.dto;

import com.bosskin.entity.UserNotification;
import lombok.*;

import java.time.LocalDateTime;
import java.util.Map;

public class NotificationDTO {

    /** Một thông báo trong hộp thư (V33). {@code data}: thông tin đi kèm (ngày công, loại đơn…), có thể rỗng. */
    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class Response {
        private Long id;
        private String type;
        private String title;
        private String body;
        private Map<String, String> data;
        private LocalDateTime createdAt;
        private boolean read;

        public static Response from(UserNotification n, Map<String, String> data) {
            return Response.builder().id(n.getId()).type(n.getType()).title(n.getTitle()).body(n.getBody())
                .data(data).createdAt(n.getCreatedAt()).read(n.getReadAt() != null).build();
        }
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class UnreadCount {
        private long count;
    }
}
