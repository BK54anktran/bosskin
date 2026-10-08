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
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Vui lòng điền ít nhất một thông tin muốn thay đổi");
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
        return editRequestRepository.findByCompanyId(user.getCompany().getId(), status)
                .stream()
                .filter(r -> finalSelectedDeptScope == null
                    || (r.getEmployee() != null
                        && r.getEmployee().getDepartment() != null
                        && finalSelectedDeptScope.contains(r.getEmployee().getDepartment().getId())))
                .map(this::toEditRequestResponse)
                .collect(Collectors.toList());
    }

    public ProfileDTO.PendingCount getPendingCount(User user) {
        requirePermission(user, "EMPLOYEE_UPDATE");
        long count = editRequestRepository.countByEmployee_Company_IdAndStatus(
                user.getCompany().getId(), ProfileEditRequest.Status.PENDING);
        return ProfileDTO.PendingCount.builder().count(count).build();
    }

    @Transactional
    public void changePassword(User user, ProfileDTO.ChangePasswordRequest req) {
        if (req.getNewPassword() == null || req.getNewPassword().trim().length() < 6) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Mật khẩu mới phải có ít nhất 6 ký tự");
        }
        if (!req.getNewPassword().equals(req.getConfirmPassword())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Mật khẩu xác nhận không khớp");
        }
        User account = userRepository.findById(user.getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Tài khoản không tồn tại"));
        if (!passwordEncoder.matches(req.getCurrentPassword(), account.getPassword())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Mật khẩu hiện tại không đúng");
        }
        account.setPassword(passwordEncoder.encode(req.getNewPassword()));
        userRepository.save(account);
        userSessionRepository.revokeAllByUserId(account.getId());
    }

    @Transactional
    public ProfileDTO.EditRequestResponse approveRequest(Long requestId, User admin) {
        requirePermission(admin, "EMPLOYEE_UPDATE");
        ProfileEditRequest req = getRequestOrThrow(requestId, admin.getCompany().getId());
        requirePending(req);

        Employee emp = req.getEmployee();
        if (req.getFullName()     != null) emp.setFullName(req.getFullName());
        if (req.getGender()       != null) emp.setGender(req.getGender());
        if (req.getDateOfBirth()  != null) emp.setDateOfBirth(req.getDateOfBirth());
        if (req.getPhone()        != null) emp.setPhone(req.getPhone());
        if (req.getPersonalEmail()!= null) emp.setPersonalEmail(req.getPersonalEmail());
        if (req.getAvatarUrl()    != null) emp.setAvatar(req.getAvatarUrl());
        employeeRepository.save(emp);

        req.setStatus(ProfileEditRequest.Status.APPROVED);
        req.setProcessedBy(admin);
        return toEditRequestResponse(editRequestRepository.save(req));
    }

    @Transactional
    public ProfileDTO.EditRequestResponse rejectRequest(Long requestId, User admin,
                                                        ProfileDTO.ProcessRequest body) {
        requirePermission(admin, "EMPLOYEE_UPDATE");
        ProfileEditRequest req = getRequestOrThrow(requestId, admin.getCompany().getId());
        requirePending(req);
        req.setStatus(ProfileEditRequest.Status.REJECTED);
        req.setProcessedBy(admin);
        req.setAdminNote(body.getAdminNote());
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

    public ProfileDTO.NotificationSettingsResponse getNotificationSettings(User user) {
        return toNotificationSettingsResponse(user);
    }

    private ProfileDTO.NotificationSettingsResponse toNotificationSettingsResponse(User u) {
        return ProfileDTO.NotificationSettingsResponse.builder()
                .enabled(u.getFcmToken() != null && u.getShiftReminderMinutes() != null)
                .shiftReminderMinutes(u.getShiftReminderMinutes())
                .checkInOutNotifMinutes(u.getCheckInOutNotifMinutes())
                .build();
    }

    // ── helpers ─────────────────────────────────────────────────────────

    private Employee getEmployeeOrThrow(User user) {
        return employeeRepository.findByUserIdFetch(user.getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Tài khoản chưa được liên kết với nhân viên nào"));
    }

    private ProfileEditRequest getRequestOrThrow(Long id, Long companyId) {
        return editRequestRepository.findByIdAndCompanyId(id, companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Không tìm thấy yêu cầu"));
    }

    private void requirePending(ProfileEditRequest req) {
        if (req.getStatus() != ProfileEditRequest.Status.PENDING) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Yêu cầu này đã được xử lý");
        }
    }

    private void requirePermission(User user, String perm) {
        if (!user.hasPermission(perm)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền: " + perm);
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
        return ProfileDTO.EditRequestResponse.builder()
                .id(r.getId())
                .employeeId(emp.getId())
                .employeeCode(emp.getEmployeeCode())
                .employeeName(emp.getFullName())
                .departmentId(emp.getDepartment().getId())
                .departmentName(emp.getDepartment().getName())
                .currentFullName(emp.getFullName())
                .currentGender(emp.getGender())
                .currentDateOfBirth(emp.getDateOfBirth())
                .currentPhone(emp.getPhone())
                .currentPersonalEmail(emp.getPersonalEmail())
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
