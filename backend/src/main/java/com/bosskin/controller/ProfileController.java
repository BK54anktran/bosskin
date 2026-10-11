package com.bosskin.controller;

import com.bosskin.dto.ProfileDTO;
import com.bosskin.entity.User;
import com.bosskin.service.ProfileService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/profile")
@RequiredArgsConstructor
public class ProfileController {

    private final ProfileService profileService;

    /** Lấy thông tin profile của user hiện tại */
    @GetMapping
    public ResponseEntity<ProfileDTO.ProfileResponse> getMyProfile(
            @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(profileService.getMyProfile(user));
    }

    /** Admin cập nhật profile trực tiếp */
    @PutMapping
    public ResponseEntity<ProfileDTO.ProfileResponse> adminUpdate(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody ProfileDTO.AdminUpdateRequest req) {
        return ResponseEntity.ok(profileService.adminUpdate(user, req));
    }

    /** Cập nhật avatar (tất cả user) */
    @PatchMapping("/avatar")
    public ResponseEntity<ProfileDTO.ProfileResponse> updateAvatar(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody ProfileDTO.AvatarUpdateRequest req) {
        return ResponseEntity.ok(profileService.updateAvatar(user, req.getAvatarUrl()));
    }

    @PatchMapping("/password")
    public ResponseEntity<Void> changePassword(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody ProfileDTO.ChangePasswordRequest req) {
        profileService.changePassword(user, req);
        return ResponseEntity.noContent().build();
    }

    /** User gửi yêu cầu chỉnh sửa thông tin */
    @PostMapping("/edit-requests")
    public ResponseEntity<ProfileDTO.EditRequestResponse> submitEditRequest(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody ProfileDTO.EditRequestCreate req) {
        return ResponseEntity.ok(profileService.submitEditRequest(user, req));
    }

    /** Admin xem danh sách yêu cầu chỉnh sửa */
    @GetMapping("/edit-requests")
    public ResponseEntity<List<ProfileDTO.EditRequestResponse>> getEditRequests(
            @AuthenticationPrincipal User user,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) Long departmentId) {
        return ResponseEntity.ok(profileService.getEditRequests(user, status, departmentId));
    }

    /** Số lượng yêu cầu đang chờ (badge) */
    @GetMapping("/edit-requests/pending-count")
    public ResponseEntity<ProfileDTO.PendingCount> getPendingCount(
            @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(profileService.getPendingCount(user));
    }

    /** Admin phê duyệt yêu cầu */
    @PutMapping("/edit-requests/{id}/approve")
    public ResponseEntity<ProfileDTO.EditRequestResponse> approveRequest(
            @PathVariable Long id,
            @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(profileService.approveRequest(id, user));
    }

    /** Admin từ chối yêu cầu */
    @PutMapping("/edit-requests/{id}/reject")
    public ResponseEntity<ProfileDTO.EditRequestResponse> rejectRequest(
            @PathVariable Long id,
            @AuthenticationPrincipal User user,
            @RequestBody ProfileDTO.ProcessRequest body) {
        return ResponseEntity.ok(profileService.rejectRequest(id, user, body));
    }

    /** Lấy trạng thái cài đặt thông báo */
    @GetMapping("/notification-settings")
    public ResponseEntity<ProfileDTO.NotificationSettingsResponse> getNotificationSettings(
            @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(profileService.getNotificationSettings(user));
    }

    /** Cập nhật FCM token và thời gian nhắc ca */
    @PatchMapping("/notification-settings")
    public ResponseEntity<ProfileDTO.NotificationSettingsResponse> updateNotificationSettings(
            @AuthenticationPrincipal User user,
            @RequestBody ProfileDTO.NotificationSettingsRequest req) {
        return ResponseEntity.ok(profileService.updateNotificationSettings(user, req));
    }

    /** Gửi thông báo thử tới thiết bị của chính mình (nút "Gửi thông báo thử" ở Hồ sơ) */
    @PostMapping("/notification-settings/test")
    public ResponseEntity<Void> sendTestNotification(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody(required = false) ProfileDTO.NotificationTestRequest req) {
        profileService.sendTestNotification(user, req);
        return ResponseEntity.noContent().build();
    }
}
