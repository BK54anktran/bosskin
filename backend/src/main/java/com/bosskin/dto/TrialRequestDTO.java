package com.bosskin.dto;

import com.bosskin.entity.TrialRequest;
import lombok.*;

import java.time.LocalDateTime;

public class TrialRequestDTO {

    /** Form công khai trên trang giới thiệu. {@code website} là ô ẩn bẫy bot — người thật để trống. */
    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class SubmitRequest {
        private String fullName;
        private String companyName;
        private String phone;
        private String email;
        private String companySize;
        private String need;
        private Boolean consent;
        private String source;
        private String website;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class UpdateRequest {
        private TrialRequest.Status status;
        private String adminNote;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class Response {
        private Long id;
        private String fullName;
        private String companyName;
        private String phone;
        private String email;
        private String companySize;
        private String need;
        private TrialRequest.Status status;
        private String adminNote;
        private String source;
        private String handledBy;
        private LocalDateTime handledAt;
        private LocalDateTime createdAt;

        public static Response of(TrialRequest t) {
            return Response.builder().id(t.getId()).fullName(t.getFullName()).companyName(t.getCompanyName())
                .phone(t.getPhone()).email(t.getEmail()).companySize(t.getCompanySize()).need(t.getNeed())
                .status(t.getStatus()).adminNote(t.getAdminNote()).source(t.getSource()).handledBy(t.getHandledBy())
                .handledAt(t.getHandledAt()).createdAt(t.getCreatedAt()).build();
        }
    }
}
