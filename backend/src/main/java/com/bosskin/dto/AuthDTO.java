package com.bosskin.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.Map;
import java.util.Set;
import lombok.*;

import java.util.Set;

public class AuthDTO {

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class LoginRequest {
        @NotBlank @Email
        private String email;
        @NotBlank @Size(min = 6)
        private String password;
        private String deviceId;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class LoginResponse {
        private String accessToken;
        private String refreshToken;
        private String tokenType;
        private Long   expiresIn;
        private UserInfo user;
    }

    @Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
    public static class UserInfo {
        private Long        id;
        private String      email;
        private String      type;          // COMPANY | SYSTEM
        private Long        companyId;
        private String      companyName;
        private String      fullName;
        private String      avatar;
        private Long        employeeId;
        private Set<String>              permissions;
        /** permCode → set of allowed deptIds (empty/absent = unrestricted) */
        private Map<String, Set<Long>>   departmentScope;
        /** true → phải đổi mật khẩu trước khi dùng các chức năng khác (V7). */
        private boolean     mustChangePassword;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class RefreshRequest {
        @NotBlank
        private String refreshToken;
        private String deviceId;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class LogoutRequest {
        private String refreshToken;
        /** FCM token của thiết bị đang đăng xuất — backend gỡ để máy không nhận thông báo của tài khoản cũ. */
        private String fcmToken;
    }
}
