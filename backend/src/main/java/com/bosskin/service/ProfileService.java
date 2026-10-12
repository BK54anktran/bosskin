package com.bosskin.service;

import com.bosskin.dto.ProfileDTO;
import com.bosskin.entity.Employee;
import com.bosskin.entity.ProfileEditRequest;
import com.bosskin.entity.User;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.ProfileEditRequestRepository;
import com.bosskin.repository.UserRepository;
import com.bosskin.repository.UserSessionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.security.crypto.password.PasswordEncoder;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ProfileService {

    private final EmployeeRepository employeeRepository;
    private final ProfileEditRequestRepository editRequestRepository;
    private final UserRepository userRepository;
    private final UserSessionRepository userSessionRepository;
    private final PasswordEncoder passwordEncoder;
    private final DeptScopeService deptScopeService;
    private final com.bosskin.audit.AuditService audit;
    private final FcmService fcmService;

    public ProfileDTO.ProfileResponse getMyProfile(User user) {
        return employeeRepository.findByUserIdFetch(user.getId())
                .map(emp -> toProfileResponse(emp, user.hasPermission("EMPLOYEE_UPDATE")))
                .orElse(ProfileDTO.ProfileResponse.builder()
                        .workEmail(user.getEmail())
                        .canEdit(user.hasPermission("EMPLOYEE_UPDATE"))
                        .build());
    }

    @Transactional
    public ProfileDTO.ProfileResponse adminUpdate(User user, ProfileDTO.AdminUpdateRequest req) {
        requirePermission(user, "EMPLOYEE_UPDATE");
        Employee emp = getEmployeeOrThrow(user);
        if (req.getFullName()     != null) emp.setFullName(req.getFullName());
        if (req.getGender()       != null) emp.setGender(req.getGender());
        if (req.getDateOfBirth()  != null) emp.setDateOfBirth(req.getDateOfBirth());
        if (req.getPhone()        != null) emp.setPhone(req.getPhone());
        if (req.getPersonalEmail()!= null) emp.setPersonalEmail(req.getPersonalEmail());
        if (req.getAvatar()       != null) emp.setAvatar(req.getAvatar());
        return toProfileResponse(employeeRepository.save(emp), true);
    }

    @Transactional
    public ProfileDTO.ProfileResponse updateAvatar(User user, String avatarUrl) {
        Employee emp = getEmployeeOrThrow(user);
        emp.setAvatar(avatarUrl);
        return toProfileResponse(employeeRepository.save(emp),
                user.hasPermission("EMPLOYEE_UPDATE"));
    }

    @Transactional
    public ProfileDTO.EditRequestResponse submitEditRequest(User user, ProfileDTO.EditRequestCreate req) {
        Employee emp = getEmployeeOrThrow(user);

        // Nếu không có trường nào thì báo lỗi
        if (req.getFullName() == null && req.getGender() == null
                && req.getDateOfBirth() == null && req.getPhone() == null
                && req.getPersonalEmail() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.profile.nothing_to_change");
        }

        ProfileEditRequest request = ProfileEditRequest.builder()
                .employee(emp)
                .fullName(req.getFullName())
                .gender(req.getGender())
                .dateOfBirth(req.getDateOfBirth())
                .phone(req.getPhone())
                .personalEmail(req.getPersonalEmail())
                .build();
        return toEditRequestResponse(editRequestRepository.save(request));
    }

    public List<ProfileDTO.EditRequestResponse> getEditRequests(User user, String statusStr, Long departmentId) {
        requirePermission(user, "EMPLOYEE_UPDATE");
        ProfileEditRequest.Status status = statusStr != null
                ? ProfileEditRequest.Status.valueOf(statusStr.toUpperCase())
                : null;
        Set<Long> selectedDeptScope = null;
        if (departmentId != null) {
            selectedDeptScope = deptScopeService.expandDepartmentsWithDescendants(Set.of(departmentId));
            if (selectedDeptScope.isEmpty()) {
                return List.of();
            }
        }
        Set<Long> finalSelectedDeptScope = selectedDeptScope;
        Set<Long> scope = updateScope(user);
        return editRequestRepository.findByCompanyId(user.getCompany().getId(), status)
                .stream()
                .filter(r -> inScope(user, scope, r.getEmployee()))
                .filter(r -> finalSelectedDeptScope == null
                    || (r.getEmployee() != null
                        && r.getEmployee().getDepartment() != null
                        && finalSelectedDeptScope.contains(r.getEmployee().getDepartment().getId())))
                .map(this::toEditRequestResponse)
                .collect(Collectors.toList());
    }

    public ProfileDTO.PendingCount getPendingCount(User user) {
        requirePermission(user, "EMPLOYEE_UPDATE");
        Set<Long> scope = updateScope(user);
        long count = scope.isEmpty()
            ? editRequestRepository.countByEmployee_Company_IdAndStatus(user.getCompany().getId(), ProfileEditRequest.Status.PENDING)
            : editRequestRepository.findByCompanyId(user.getCompany().getId(), ProfileEditRequest.Status.PENDING).stream()
                .filter(r -> inScope(user, scope, r.getEmployee())).count();
        return ProfileDTO.PendingCount.builder().count(count).build();
    }

    @Transactional
    public void changePassword(User user, ProfileDTO.ChangePasswordRequest req) {
        com.bosskin.core.PasswordPolicy.require(req.getNewPassword());
        if (!req.getNewPassword().equals(req.getConfirmPassword())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.password.confirm_mismatch");
        }
        User account = userRepository.findById(user.getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.user.not_found"));
        if (!passwordEncoder.matches(req.getCurrentPassword(), account.getPassword())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.password.current_wrong");
        }
        if (passwordEncoder.matches(req.getNewPassword(), account.getPassword())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.password.same_as_current");
        }
        account.setPassword(passwordEncoder.encode(req.getNewPassword()));
        account.setMustChangePassword(false);
        userRepository.save(account);
        userSessionRepository.revokeAllByUserId(account.getId());
    }

    @Transactional
    public ProfileDTO.EditRequestResponse approveRequest(Long requestId, User admin) {
        requirePermission(admin, "EMPLOYEE_UPDATE");
        ProfileEditRequest req = getRequestOrThrow(requestId, admin.getCompany().getId());
        requirePending(req);
        requireCanProcess(admin, req);

        Employee emp = req.getEmployee();
        // D11: giữ giá trị cũ để xem lại / đối chiếu sau khi duyệt
        req.setOldFullName(emp.getFullName());
        req.setOldGender(emp.getGender());
        req.setOldDateOfBirth(emp.getDateOfBirth());
        req.setOldPhone(emp.getPhone());
        req.setOldPersonalEmail(emp.getPersonalEmail());
        if (req.getFullName()     != null) emp.setFullName(req.getFullName());
        if (req.getGender()       != null) emp.setGender(req.getGender());
        if (req.getDateOfBirth()  != null) emp.setDateOfBirth(req.getDateOfBirth());
        if (req.getPhone()        != null) emp.setPhone(req.getPhone());
        if (req.getPersonalEmail()!= null) emp.setPersonalEmail(req.getPersonalEmail());
        if (req.getAvatarUrl()    != null) emp.setAvatar(req.getAvatarUrl());
        employeeRepository.save(emp);

        req.setStatus(ProfileEditRequest.Status.APPROVED);
        req.setProcessedBy(admin);
        req.setProcessedAt(java.time.LocalDateTime.now());
        audit.log("PROFILE_EDIT_APPROVE").entity("EMPLOYEE", emp.getId()).summary(emp.getEmployeeCode())
            .detail(com.bosskin.audit.AuditService.map(
                "before", changedFields(req, true), "after", changedFields(req, false))).save();
        return toEditRequestResponse(editRequestRepository.save(req));
    }

    @Transactional
    public ProfileDTO.EditRequestResponse rejectRequest(Long requestId, User admin,
                                                        ProfileDTO.ProcessRequest body) {
        requirePermission(admin, "EMPLOYEE_UPDATE");
        ProfileEditRequest req = getRequestOrThrow(requestId, admin.getCompany().getId());
        requirePending(req);
        requireCanProcess(admin, req);
        req.setStatus(ProfileEditRequest.Status.REJECTED);
        req.setProcessedBy(admin);
        req.setProcessedAt(java.time.LocalDateTime.now());
        req.setAdminNote(body.getAdminNote());
        audit.log("PROFILE_EDIT_REJECT").entity("EMPLOYEE", req.getEmployee().getId())
            .summary(req.getEmployee().getEmployeeCode()).save();
        return toEditRequestResponse(editRequestRepository.save(req));
    }

    @Transactional
    public ProfileDTO.NotificationSettingsResponse updateNotificationSettings(
            User user, ProfileDTO.NotificationSettingsRequest req) {
        User u = userRepository.findById(user.getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.user.not_found"));
        if (req.getFcmToken() != null && !req.getFcmToken().isBlank()) {
            userRepository.clearFcmTokenFromOthers(req.getFcmToken(), u.getId());
            u.setFcmToken(req.getFcmToken());
        }
        u.setShiftReminderMinutes(req.getShiftReminderMinutes());
        u.setCheckInOutNotifMinutes(req.getCheckInOutNotifMinutes());
        userRepository.save(u);
        return toNotificationSettingsResponse(u);
    }

    /**
     * Gửi một thông báo thử tới thiết bị của chính người gọi (token đọc lại từ DB, không nhận token từ client).
     * Chạy ngoài transaction chỉ-đọc của lớp: FCM báo token chết thì {@code FcmService} phải gỡ token (ghi DB),
     * và không giữ kết nối DB trong lúc gọi mạng.
     */
    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    public void sendTestNotification(User user, ProfileDTO.NotificationTestRequest req) {
        User u = userRepository.findById(user.getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.user.not_found"));
        String title = req != null && req.getTitle() != null && !req.getTitle().isBlank() ? req.getTitle().trim() : "BossKin";
        String body  = req != null && req.getBody()  != null && !req.getBody().isBlank()  ? req.getBody().trim()  : "Test";
        fcmService.sendTest(u.getFcmToken(), title, body);
    }

    public ProfileDTO.NotificationSettingsResponse getNotificationSettings(User user) {
        return toNotificationSettingsResponse(user);
    }

    private ProfileDTO.NotificationSettingsResponse toNotificationSettingsResponse(User u) {
        return ProfileDTO.NotificationSettingsResponse.builder()
                .enabled(u.getShiftReminderMinutes() != null || u.getCheckInOutNotifMinutes() != null)
                .deviceRegistered(u.getFcmToken() != null)
                .shiftReminderMinutes(u.getShiftReminderMinutes())
                .checkInOutNotifMinutes(u.getCheckInOutNotifMinutes())
                .build();
    }

    // ── helpers ─────────────────────────────────────────────────────────

    private Employee getEmployeeOrThrow(User user) {
        return employeeRepository.findByUserIdFetch(user.getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "error.user.employee_not_linked"));
    }

    private ProfileEditRequest getRequestOrThrow(Long id, Long companyId) {
        return editRequestRepository.findByIdAndCompanyId(id, companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "error.request.not_found"));
    }

    private Set<Long> updateScope(User user) {
        return deptScopeService.resolvedScopes(user.getId(), "EMPLOYEE_UPDATE");
    }

    /** D11: phạm vi phòng ban của quyền EMPLOYEE_UPDATE (rỗng = toàn công ty). */
    private static boolean inScope(User user, Set<Long> scope, Employee e) {
        if (scope.isEmpty()) return true;
        if (e == null) return false;
        if (scope.contains(DeptScopeService.SCOPE_SELF_ONLY)
                && user.getEmployee() != null && user.getEmployee().getId().equals(e.getId())) return true;
        return e.getDepartment() != null && scope.contains(e.getDepartment().getId());
    }

    /** D11: chỉ duyệt đơn trong phạm vi, và không tự duyệt đơn sửa hồ sơ của chính mình. */
    private void requireCanProcess(User admin, ProfileEditRequest req) {
        Employee e = req.getEmployee();
        if (admin.getEmployee() != null && e != null && admin.getEmployee().getId().equals(e.getId()))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.profile.cannot_process_own");
        if (!inScope(admin, updateScope(admin), e))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.department_scope");
    }

    /** Trường được yêu cầu sửa: giá trị cũ (before) hoặc mới (after) — cho nhật ký thao tác. */
    private static java.util.Map<String, Object> changedFields(ProfileEditRequest r, boolean before) {
        java.util.Map<String, Object> m = new java.util.LinkedHashMap<>();
        if (r.getFullName() != null)      m.put("fullName", before ? r.getOldFullName() : r.getFullName());
        if (r.getGender() != null)        m.put("gender", before ? r.getOldGender() : r.getGender());
        if (r.getDateOfBirth() != null)   m.put("dateOfBirth", String.valueOf(before ? r.getOldDateOfBirth() : r.getDateOfBirth()));
        if (r.getPhone() != null)         m.put("phone", before ? r.getOldPhone() : r.getPhone());
        if (r.getPersonalEmail() != null) m.put("personalEmail", before ? r.getOldPersonalEmail() : r.getPersonalEmail());
        return m;
    }

    private void requirePending(ProfileEditRequest req) {
        if (req.getStatus() != ProfileEditRequest.Status.PENDING) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "error.request.already_processed");
        }
    }

    private void requirePermission(User user, String perm) {
        if (!user.hasPermission(perm)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }

    private ProfileDTO.ProfileResponse toProfileResponse(Employee e, boolean canEdit) {
        return ProfileDTO.ProfileResponse.builder()
                .id(e.getId())
                .employeeCode(e.getEmployeeCode())
                .fullName(e.getFullName())
                .workEmail(e.getEmail())
                .personalEmail(e.getPersonalEmail())
                .phone(e.getPhone())
                .avatar(e.getAvatar())
                .gender(e.getGender())
                .dateOfBirth(e.getDateOfBirth())
                .joinDate(e.getJoinDate())
                .departmentName(e.getDepartment().getName())
                .positionName(e.getPosition() != null ? e.getPosition().getName() : null)
                .status(e.getStatus())
                .canEdit(canEdit)
                .build();
    }

    private ProfileDTO.EditRequestResponse toEditRequestResponse(ProfileEditRequest r) {
        Employee emp = r.getEmployee();
        boolean snap = r.getStatus() == ProfileEditRequest.Status.APPROVED && r.getProcessedAt() != null;
        return ProfileDTO.EditRequestResponse.builder()
                .id(r.getId())
                .employeeId(emp.getId())
                .employeeCode(emp.getEmployeeCode())
                .employeeName(emp.getFullName())
                .departmentId(emp.getDepartment().getId())
                .departmentName(emp.getDepartment().getName())
                // D11: đơn đã duyệt hiện giá trị lúc trước khi duyệt, không phải giá trị đang có
                .currentFullName(snap ? r.getOldFullName() : emp.getFullName())
                .currentGender(snap ? r.getOldGender() : emp.getGender())
                .currentDateOfBirth(snap ? r.getOldDateOfBirth() : emp.getDateOfBirth())
                .currentPhone(snap ? r.getOldPhone() : emp.getPhone())
                .currentPersonalEmail(snap ? r.getOldPersonalEmail() : emp.getPersonalEmail())
                .requestedFullName(r.getFullName())
                .requestedGender(r.getGender())
                .requestedDateOfBirth(r.getDateOfBirth())
                .requestedPhone(r.getPhone())
                .requestedPersonalEmail(r.getPersonalEmail())
                .status(r.getStatus())
                .adminNote(r.getAdminNote())
                .createdAt(r.getCreatedAt())
                .processedAt(r.getUpdatedAt())
                .build();
    }
}
