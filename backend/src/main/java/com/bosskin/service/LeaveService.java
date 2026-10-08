package com.bosskin.service;

import com.bosskin.dto.LeaveDTO;
import com.bosskin.entity.*;
import com.bosskin.repository.*;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class LeaveService {

    private final LeaveTypeRepository leaveTypeRepository;
    private final PeriodLockService periodLockService;
    private final LeaveGrantRepository leaveGrantRepository;
    private final LeaveLedgerEntryRepository ledgerRepository;
    private final LeaveRequestRepository leaveRequestRepository;
    private final LeaveAccrualRuleRepository leaveAccrualRuleRepository;
    private final EmployeeRepository employeeRepository;
    private final DepartmentRepository departmentRepository;
    private final CompanyRepository companyRepository;
    private final DeptScopeService deptScopeService;
    private final AttendanceRepository attendanceRepository;

    @PersistenceContext
    private EntityManager entityManager;

    public List<LeaveDTO.LeaveTypeResponse> getTypes(Long companyId) {
        return leaveTypeRepository.findByCompanyIdAndDeletedFalseOrderByNameAsc(companyId).stream()
            .map(this::toLeaveTypeResponse)
            .toList();
    }

    @Transactional
    public LeaveDTO.LeaveTypeResponse createType(Long companyId, LeaveDTO.LeaveTypeUpsert req) {
        if (leaveTypeRepository.existsByCompanyIdAndCodeIgnoreCaseAndDeletedFalse(companyId, req.getCode())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.leave_type.code_duplicate");
        }
        LeaveType type = LeaveType.builder()
            .company(companyRef(companyId))
            .code(req.getCode().trim().toUpperCase())
            .name(req.getName().trim())
            .unit(req.getUnit())
            .deductPerDay(normalizeDeductPerDay(req.getUnit(), req.getDeductPerDay()))
            .paid(Boolean.TRUE.equals(req.getPaid()))
            .requiresBalance(req.getRequiresBalance() != null ? req.getRequiresBalance() : Boolean.TRUE.equals(req.getPaid()))
            .active(Boolean.TRUE.equals(req.getActive()))
            .description(req.getDescription())
            .build();
        return toLeaveTypeResponse(leaveTypeRepository.save(type));
    }

    @Transactional
    public LeaveDTO.LeaveTypeResponse updateType(Long companyId, Long id, LeaveDTO.LeaveTypeUpsert req) {
        LeaveType type = leaveTypeRepository.findByIdAndCompanyIdAndDeletedFalse(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.leave_type.not_found"));
        if (leaveTypeRepository.existsByCompanyIdAndCodeIgnoreCaseAndIdNotAndDeletedFalse(companyId, req.getCode(), id)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.leave_type.code_duplicate");
        }
        type.setCode(req.getCode().trim().toUpperCase());
        type.setName(req.getName().trim());
        type.setUnit(req.getUnit());
        type.setDeductPerDay(normalizeDeductPerDay(req.getUnit(), req.getDeductPerDay()));
        type.setPaid(Boolean.TRUE.equals(req.getPaid()));
        type.setRequiresBalance(req.getRequiresBalance() != null ? req.getRequiresBalance() : Boolean.TRUE.equals(req.getPaid()));
        type.setActive(Boolean.TRUE.equals(req.getActive()));
        type.setDescription(req.getDescription());
        return toLeaveTypeResponse(leaveTypeRepository.save(type));
    }

    @Transactional
    public void deleteType(Long companyId, Long id) {
        LeaveType type = leaveTypeRepository.findByIdAndCompanyIdAndDeletedFalse(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.leave_type.not_found"));
        type.setDeleted(true);
        type.setActive(false);
        leaveTypeRepository.save(type);
    }

    public List<LeaveDTO.LeaveRequestResponse> getRequests(User user, String statusStr, Long departmentId) {
        LeaveRequest.Status status = statusStr == null || statusStr.isBlank() ? null : LeaveRequest.Status.valueOf(statusStr.toUpperCase());
        Set<Long> selectedDeptScope = null;
        if (departmentId != null) {
            selectedDeptScope = deptScopeService.expandDepartmentsWithDescendants(Set.of(departmentId));
            if (selectedDeptScope.isEmpty()) return List.of();
        }

        List<LeaveRequest> requests;
        if (isManager(user)) {
            requests = leaveRequestRepository.findByCompanyAndStatus(user.getCompanyId(), status);
        } else {
            Employee self = getEmployeeOrThrow(user);
            if (selectedDeptScope != null && (self.getDepartment() == null || !selectedDeptScope.contains(self.getDepartment().getId()))) {
                return List.of();
            }
            requests = leaveRequestRepository.findByEmployeeIdOrderByCreatedAtDesc(self.getId()).stream()
                .filter(r -> status == null || r.getStatus() == status)
                .toList();
        }

        requests = filterByLeaveViewScope(requests, user, selectedDeptScope);
        // Chỉ trả đơn cha hoặc đơn đơn lẻ (không trả đơn con riêng)
        return requests.stream()
            .filter(r -> r.getParent() == null)
            .map(this::toLeaveRequestResponse).toList();
    }

    /** Như {@link #getRequests} nhưng lọc, tìm kiếm và phân trang ở DB (F9). */
    @Transactional(readOnly = true)
    public com.bosskin.dto.PageResponse<LeaveDTO.LeaveRequestResponse> searchRequests(
            User user, String statusStr, Long departmentId, String q, int page, int size) {
        LeaveRequest.Status status = statusStr == null || statusStr.isBlank() ? null : LeaveRequest.Status.valueOf(statusStr.toUpperCase());
        var pageable = org.springframework.data.domain.PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), 200));

        Long employeeId = null;
        if (!isManager(user)) employeeId = getEmployeeOrThrow(user).getId();

        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "LEAVE_VIEW");
        if (scope.contains(DeptScopeService.SCOPE_SELF_ONLY)) {
            Long mine = employeeRepository.findByUserIdFetch(user.getId()).map(Employee::getId).orElse(null);
            if (mine == null || (employeeId != null && !employeeId.equals(mine))) {
                return com.bosskin.dto.PageResponse.of(org.springframework.data.domain.Page.empty(pageable));
            }
            employeeId = mine;
        }
        Set<Long> deptIds = scope.stream().filter(id -> id > 0).collect(Collectors.toSet());
        boolean anyDept = deptIds.isEmpty();
        if (departmentId != null) {
            Set<Long> selected = new java.util.HashSet<>(deptScopeService.expandDepartmentsWithDescendants(Set.of(departmentId)));
            if (!anyDept) selected.retainAll(deptIds);
            deptIds = selected;
            anyDept = false;
        }
        if (!anyDept && deptIds.isEmpty()) {
            return com.bosskin.dto.PageResponse.of(org.springframework.data.domain.Page.empty(pageable));
        }
        String like = q == null || q.isBlank() ? null : "%" + q.trim().toLowerCase() + "%";
        var result = leaveRequestRepository.searchPage(user.getCompanyId(), status, employeeId,
                anyDept, anyDept ? Set.of(-1L) : deptIds, like, pageable);
        return com.bosskin.dto.PageResponse.of(result.map(this::toLeaveRequestResponse));
    }

    @Transactional
    public LeaveDTO.LeaveRequestResponse createRequest(User user, LeaveDTO.CreateLeaveRequest req) {
        Employee emp;
        if (req.getEmployeeId() != null) {
            emp = employeeRepository.findByIdAndCompanyId(req.getEmployeeId(), user.getCompanyId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
            Long selfEmployeeId = user.getEmployeeId();
            boolean isSelf = selfEmployeeId != null && selfEmployeeId.equals(emp.getId());
            if (!isSelf) {
                requirePermission(user, "LEAVE_REQUEST_CREATE_FOR_OTHERS");
                requireLeaveViewScope(user, emp);
            }
        } else {
            emp = getEmployeeOrThrow(user);
        }

        LeaveType type = leaveTypeRepository.findByIdAndCompanyIdAndDeletedFalse(req.getLeaveTypeId(), user.getCompanyId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.leave_type.not_found"));
        if (!type.isActive()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.leave_type.inactive");
        }
        // L12: loại tính theo ngày xin theo khoảng ngày, loại tính theo giờ xin theo khoảng giờ
        LeaveRequest.Mode expectedMode = type.getUnit() == LeaveType.Unit.HOUR
            ? LeaveRequest.Mode.HOUR_RANGE : LeaveRequest.Mode.DAY_RANGE;
        if (req.getMode() != expectedMode) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.leave.mode_mismatch");
        }

        if (req.getToDate().isBefore(req.getFromDate())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.date.range_invalid");
        }
        periodLockService.requireOpen(emp.getCompany().getId(), req.getFromDate(), req.getToDate());
        requireNoOverlap(emp.getId(), req);
        BigDecimal hpdReq = loadHoursPerDay(user.getCompanyId());
        boolean isHourType = type.getUnit() == LeaveType.Unit.HOUR;
        boolean isMultiDay = !req.getFromDate().equals(req.getToDate());

        if (isMultiDay) {
            return createGroupRequest(user, emp, type, req, hpdReq, isHourType);
        }

        BigDecimal requestedAmount = calculateRequestedAmount(req, type);
        if (type.isRequiresBalance()) { // L8: loại không trừ quỹ thì không kiểm/trừ số dư
            List<LeaveGrant> usable = leaveGrantRepository.findUsableGrantsForType(emp.getId(), type.getId(), req.getFromDate());
            BigDecimal available = usable.stream()
                .map(g -> isHourType ? availableHours(g, hpdReq) : availableDays(g, hpdReq))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
            if (available.compareTo(requestedAmount) < 0) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.leave.insufficient_balance");
            }
        }

        LeaveRequest request = LeaveRequest.builder()
            .company(companyRef(user.getCompanyId()))
            .employee(emp)
            .leaveType(type)
            .mode(req.getMode())
            .fromDate(req.getFromDate())
            .toDate(req.getToDate())
            .fromTime(req.getFromTime())
            .toTime(req.getToTime())
            .requestedAmount(requestedAmount)
            .reason(req.getReason())
            .build();
        request = leaveRequestRepository.save(request);
        if (type.isRequiresBalance()) {
            deductWithLedger(request, emp, isHourType, requestedAmount, hpdReq);
        }
        return saveAndReload(request, user.getCompanyId());
    }

    @Transactional
    public LeaveDTO.LeaveRequestResponse approveRequest(Long id, User admin, LeaveDTO.ProcessLeaveRequest body) {
        requirePermission(admin, "LEAVE_REQUEST_APPROVE");
        Long companyId = admin.getCompanyId();
        LeaveRequest request = getRequestOrThrow(id, companyId);
        periodLockService.requireOpen(companyId, request.getFromDate(), request.getToDate());
        requireLeaveViewScope(admin, request.getEmployee());
        if (admin.getEmployeeId() != null && admin.getEmployeeId().equals(request.getEmployee().getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.leave.cannot_process_own");
        }
        if (request.getStatus() != LeaveRequest.Status.PENDING) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.request.not_pending");
        }
        // Nếu là đơn cha (group), approve tất cả đơn con PENDING
        if (!request.getChildren().isEmpty()) {
            for (LeaveRequest child : request.getChildren()) {
                if (child.getStatus() == LeaveRequest.Status.PENDING) {
                    child.setStatus(LeaveRequest.Status.APPROVED);
                    child.setAdminNote(body != null ? body.getAdminNote() : null);
                    child.setProcessedBy(admin);
                    child.setProcessedAt(java.time.LocalDateTime.now());
                    leaveRequestRepository.save(child);
                }
            }
        }
        request.setStatus(LeaveRequest.Status.APPROVED);
        request.setAdminNote(body != null ? body.getAdminNote() : null);
        request.setProcessedBy(admin);
        request.setProcessedAt(java.time.LocalDateTime.now());
        return saveAndReload(request, companyId);
    }

    @Transactional
    public LeaveDTO.LeaveRequestResponse rejectRequest(Long id, User admin, LeaveDTO.ProcessLeaveRequest body) {
        requirePermission(admin, "LEAVE_REQUEST_APPROVE");
        Long companyId = admin.getCompanyId();
        LeaveRequest request = getRequestOrThrow(id, companyId);
        periodLockService.requireOpen(companyId, request.getFromDate(), request.getToDate());
        requireLeaveViewScope(admin, request.getEmployee());
        if (admin.getEmployeeId() != null && admin.getEmployeeId().equals(request.getEmployee().getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.leave.cannot_process_own");
        }
        if (request.getStatus() != LeaveRequest.Status.PENDING) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.request.not_pending");
        }
        BigDecimal hpd = loadHoursPerDay(companyId);
        // Nếu là đơn cha, reject + hoàn phép từng đơn con PENDING
        if (!request.getChildren().isEmpty()) {
            for (LeaveRequest child : request.getChildren()) {
                if (child.getStatus() == LeaveRequest.Status.PENDING) {
                    refundBalance(child, hpd);
                    child.setStatus(LeaveRequest.Status.REJECTED);
                    child.setAdminNote(body != null ? body.getAdminNote() : null);
                    child.setProcessedBy(admin);
                    child.setProcessedAt(java.time.LocalDateTime.now());
                    leaveRequestRepository.save(child);
                }
            }
        } else {
            refundBalance(request, hpd);
        }
        request.setStatus(LeaveRequest.Status.REJECTED);
        request.setAdminNote(body != null ? body.getAdminNote() : null);
        request.setProcessedBy(admin);
        request.setProcessedAt(java.time.LocalDateTime.now());
        return saveAndReload(request, companyId);
    }

    @Transactional
    public LeaveDTO.LeaveRequestResponse cancelRequest(Long id, User user) {
        Long companyId = user.getCompanyId();
        LeaveRequest request = getRequestOrThrow(id, companyId);
        periodLockService.requireOpen(companyId, request.getFromDate(), request.getToDate());
        // L9: chủ đơn chỉ huỷ được đơn đang chờ; huỷ đơn đã duyệt cần quyền duyệt phép + phạm vi.
        // Kỳ đã khoá thì không huỷ được (kiểm ở trên). Trước đây xác định admin theo tên vai trò.
        boolean isOwner = user.getEmployeeId() != null
            && user.getEmployeeId().equals(request.getEmployee().getId());
        boolean canProcess = user.hasPermission("LEAVE_REQUEST_APPROVE");
        if (canProcess && !isOwner) {
            requireLeaveViewScope(user, request.getEmployee());
        } else if (isOwner) {
            if (request.getStatus() != LeaveRequest.Status.PENDING && !canProcess) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "error.leave.cancel_only_pending");
            }
        } else {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.request.cancel_forbidden");
        }
        if (request.getStatus() == LeaveRequest.Status.CANCELLED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.request.already_cancelled");
        }
        BigDecimal hpd = loadHoursPerDay(companyId);
        // Nếu là đơn cha, cancel từng đơn con và unapprove attendance nếu cần
        if (!request.getChildren().isEmpty()) {
            for (LeaveRequest child : request.getChildren()) {
                if (child.getStatus() != LeaveRequest.Status.CANCELLED) {
                    if (child.getStatus() != LeaveRequest.Status.REJECTED) {
                        refundBalance(child, hpd);
                    }
                    unapproveAttendanceForLeave(child);
                    child.setStatus(LeaveRequest.Status.CANCELLED);
                    child.setProcessedAt(java.time.LocalDateTime.now());
                    leaveRequestRepository.save(child);
                }
            }
        } else {
            if (request.getStatus() != LeaveRequest.Status.REJECTED) {
                refundBalance(request, hpd);
            }
            unapproveAttendanceForLeave(request);
        }
        request.setStatus(LeaveRequest.Status.CANCELLED);
        request.setProcessedAt(java.time.LocalDateTime.now());
        return saveAndReload(request, companyId);
    }

    private void unapproveAttendanceForLeave(LeaveRequest lr) {
        for (LocalDate d = lr.getFromDate(); !d.isAfter(lr.getToDate()); d = d.plusDays(1)) {
            for (var att : attendanceRepository.findByEmployeeIdAndDate(lr.getEmployee().getId(), d)) {
                    if (att.isApproved()) {
                        att.setApproved(false);
                        att.setApprovedAt(null);
                        att.setApprovedBy(null);
                        att.setSnapActualHours(null);
                        att.setSnapDayHours(null);
                        att.setSnapDayOt(null);
                        att.setSnapNightHours(null);
                        att.setSnapNightOt(null);
                        attendanceRepository.save(att);
                    }
            }
        }
    }

    @Transactional
    public LeaveDTO.LeaveRequestResponse updateApplied(Long id, User admin, boolean applied) {
        requirePermission(admin, "LEAVE_REQUEST_APPROVE");
        Long companyId = admin.getCompanyId();
        LeaveRequest request = getRequestOrThrow(id, companyId);
        periodLockService.requireOpen(companyId, request.getFromDate(), request.getToDate());
        requireLeaveViewScope(admin, request.getEmployee());
        if (admin.getEmployeeId() != null && admin.getEmployeeId().equals(request.getEmployee().getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.leave.cannot_process_own");
        }
        if (request.getStatus() != LeaveRequest.Status.APPROVED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.request.not_approved");
        }
        request.setApplied(applied);
        return saveAndReload(request, companyId);
    }

    @Transactional
    public LeaveDTO.LeaveGrantResponse createManualGrant(User admin, LeaveDTO.ManualGrantRequest req) {
        requirePermission(admin, "LEAVE_GRANT_MANUAL");
        Long companyId = admin.getCompanyId();
        Employee employee = employeeRepository.findByIdAndCompanyId(req.getEmployeeId(), companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
        requireLeaveViewScope(admin, employee);
        LeaveType leaveType = null;
        if (req.getLeaveTypeId() != null) {
            leaveType = leaveTypeRepository.findByIdAndCompanyIdAndDeletedFalse(req.getLeaveTypeId(), companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.leave_type.not_found"));
        }

        if (req.getGrantDays() == null && req.getGrantHours() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.leave.amount_required");
        }
        LocalDate grantedAt = req.getGrantedAt() != null ? req.getGrantedAt() : LocalDate.now();
        LocalDate validFrom = req.getValidFrom();
        LocalDate validTo = req.getValidTo();
        if (req.getExpireAfterDays() != null) {
            validFrom = validFrom != null ? validFrom : grantedAt;
            validTo = validFrom.plusDays(req.getExpireAfterDays());
        }
        if (validFrom != null && validTo != null && validTo.isBefore(validFrom)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.leave.validity_invalid");
        }

        LeaveGrant grant = LeaveGrant.builder()
            .company(companyRef(companyId))
            .employee(employee)
            .leaveType(leaveType)
            .source(LeaveGrant.Source.MANUAL)
            .grantDays(req.getGrantDays() != null ? req.getGrantDays().setScale(2, RoundingMode.HALF_UP) : null)
            .grantHours(req.getGrantHours() != null ? req.getGrantHours().setScale(2, RoundingMode.HALF_UP) : null)
            .grantedAt(grantedAt)
            .validFrom(validFrom)
            .validTo(validTo)
            .note(req.getNote())
            .build();
        normalizeGrantAmount(grant, loadHoursPerDay(companyId));
        return toLeaveGrantResponse(leaveGrantRepository.save(grant));
    }

    public List<LeaveDTO.LeaveGrantResponse> getGrants(User user, Long employeeId, Long leaveTypeId, Long departmentId) {
        requirePermission(user, "LEAVE_VIEW");
        Set<Long> selectedDeptScope = null;
        if (departmentId != null) {
            selectedDeptScope = deptScopeService.expandDepartmentsWithDescendants(Set.of(departmentId));
            if (selectedDeptScope.isEmpty()) return List.of();
        }
        List<LeaveGrant> grants = leaveGrantRepository.findForCompany(user.getCompanyId(), employeeId, leaveTypeId);
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "LEAVE_VIEW");
        boolean selfOnly = scope.contains(DeptScopeService.SCOPE_SELF_ONLY);
        Set<Long> deptScope = scope.stream().filter(id -> id > 0).collect(Collectors.toSet());
        Long myEmpId = selfOnly ? employeeRepository.findByUserIdFetch(user.getId())
            .map(Employee::getId).orElse(null) : null;
        final Set<Long> finalSelectedDeptScope = selectedDeptScope;
        return grants.stream()
            .filter(g -> g.getEmployee() != null)
            .filter(g -> {
                if (selfOnly) return myEmpId != null && myEmpId.equals(g.getEmployee().getId());
                if (deptScope.isEmpty()) return true;
                return g.getEmployee().getDepartment() != null
                    && deptScope.contains(g.getEmployee().getDepartment().getId());
            })
            .filter(g -> finalSelectedDeptScope == null
                || (g.getEmployee().getDepartment() != null
                    && finalSelectedDeptScope.contains(g.getEmployee().getDepartment().getId())))
            .map(this::toLeaveGrantResponse)
            .toList();
    }

    public List<LeaveDTO.LeaveAccrualRuleResponse> getAccrualRules(Long companyId) {
        return leaveAccrualRuleRepository.findByCompanyIdAndDeletedFalseOrderByCreatedAtDesc(companyId)
            .stream().map(this::toRuleResponse).toList();
    }

    public LeaveDTO.LeaveSettingResponse getSetting(Long companyId) {
        Company c = companyRepository.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.company.not_found"));
        return LeaveDTO.LeaveSettingResponse.builder()
            .leaveHoursPerDay(c.getLeaveHoursPerDay())
            .build();
    }

    @Transactional
    public LeaveDTO.LeaveSettingResponse updateSetting(Long companyId, LeaveDTO.LeaveSettingUpsert req) {
        Company c = companyRepository.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.company.not_found"));
        if (req.getLeaveHoursPerDay() == null || req.getLeaveHoursPerDay().compareTo(BigDecimal.ZERO) <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.company.hours_per_day_invalid");
        }
        c.setLeaveHoursPerDay(req.getLeaveHoursPerDay().setScale(2, RoundingMode.HALF_UP));
        companyRepository.save(c);
        return LeaveDTO.LeaveSettingResponse.builder()
            .leaveHoursPerDay(c.getLeaveHoursPerDay())
            .build();
    }

    @Transactional
    public LeaveDTO.LeaveAccrualRuleResponse createAccrualRule(Long companyId, LeaveDTO.LeaveAccrualRuleUpsert req) {
        Department department = null;
        if (req.getDepartmentId() != null) {
            department = departmentRepository.findByIdAndCompanyId(req.getDepartmentId(), companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.department.not_found"));
        }
        validateRule(req);
        LeaveAccrualRule rule = LeaveAccrualRule.builder()
            .company(companyRef(companyId))
            .department(department)
            .name(req.getName().trim())
            .grantDays(req.getGrantDays())
            .grantHours(req.getGrantHours())
            .frequency(req.getFrequency())
            .dayOfMonth(req.getDayOfMonth())
            .monthOfYear(req.getMonthOfYear())
            .minTenureYears(req.getMinTenureYears() == null ? 0 : req.getMinTenureYears())
            .validFrom(req.getValidFrom())
            .validTo(req.getValidTo())
            .expireAfterDays(req.getExpireAfterDays())
            .active(Boolean.TRUE.equals(req.getActive()))
            .build();
        return toRuleResponse(leaveAccrualRuleRepository.save(rule));
    }

    @Transactional
    public LeaveDTO.LeaveAccrualRuleResponse updateAccrualRule(Long companyId, Long id, LeaveDTO.LeaveAccrualRuleUpsert req) {
        LeaveAccrualRule rule = leaveAccrualRuleRepository.findByIdAndCompanyIdAndDeletedFalse(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.leave_rule.not_found"));
        Department department = null;
        if (req.getDepartmentId() != null) {
            department = departmentRepository.findByIdAndCompanyId(req.getDepartmentId(), companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.department.not_found"));
        }
        validateRule(req);
        rule.setDepartment(department);
        rule.setName(req.getName().trim());
        rule.setGrantDays(req.getGrantDays());
        rule.setGrantHours(req.getGrantHours());
        rule.setFrequency(req.getFrequency());
        rule.setDayOfMonth(req.getDayOfMonth());
        rule.setMonthOfYear(req.getMonthOfYear());
        rule.setMinTenureYears(req.getMinTenureYears() == null ? 0 : req.getMinTenureYears());
        rule.setValidFrom(req.getValidFrom());
        rule.setValidTo(req.getValidTo());
        rule.setExpireAfterDays(req.getExpireAfterDays());
        rule.setActive(Boolean.TRUE.equals(req.getActive()));
        return toRuleResponse(leaveAccrualRuleRepository.save(rule));
    }

    @Transactional
    public void deleteAccrualRule(Long companyId, Long id) {
        LeaveAccrualRule rule = leaveAccrualRuleRepository.findByIdAndCompanyIdAndDeletedFalse(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.leave_rule.not_found"));
        rule.setDeleted(true);
        rule.setActive(false);
        leaveAccrualRuleRepository.save(rule);
    }

    @Transactional
    public Map<String, Integer> runAccrual(User user, LocalDate runDate) {
        requirePermission(user, "LEAVE_ACCRUAL_MANAGE");
        return runAccrualForCompany(user.getCompanyId(), runDate != null ? runDate : LocalDate.now());
    }

    /**
     * Cộng phép tự động theo quy tắc cho một công ty vào một ngày (L10).
     * Chạy lại cùng ngày không cộng trùng (kiểm grant đã có trong kỳ).
     * Dùng chung cho nút "Chạy" thủ công và job chạy hằng ngày (LeaveAccrualScheduler).
     */
    @Transactional
    public Map<String, Integer> runAccrualForCompany(Long companyId, LocalDate date) {
        Company company = companyRepository.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.company.not_found"));
        BigDecimal hoursPerDay = company.getLeaveHoursPerDay() != null && company.getLeaveHoursPerDay().compareTo(BigDecimal.ZERO) > 0
            ? company.getLeaveHoursPerDay() : BigDecimal.valueOf(8);
        List<LeaveAccrualRule> rules = leaveAccrualRuleRepository.findByCompanyIdAndDeletedFalseOrderByCreatedAtDesc(companyId)
            .stream().filter(LeaveAccrualRule::isActive).toList();
        List<Employee> employees = employeeRepository.findByCompanyId(companyId);
        int created = 0;

        for (LeaveAccrualRule rule : rules) {
            boolean ruleMatches = switch (rule.getFrequency()) {
                case MONTHLY -> matchesDayOfMonth(rule.getDayOfMonth(), date);
                case YEARLY -> rule.getMonthOfYear() != null
                    && rule.getMonthOfYear().equals(date.getMonthValue())
                    && matchesDayOfMonth(rule.getDayOfMonth(), date);
            };
            if (!ruleMatches) continue;

            for (Employee e : employees) {
                if (rule.getDepartment() != null &&
                    (e.getDepartment() == null || !rule.getDepartment().getId().equals(e.getDepartment().getId()))) {
                    continue;
                }
                // Chỉ nhân viên đang làm, đã vào làm trước ngày cộng
                if (e.getJoinDate() == null || e.getJoinDate().isAfter(date)) continue;
                if (e.getStatus() != null && e.getStatus() != Employee.Status.ACTIVE) continue;
                // Thâm niên tính đủ năm theo ngày vào làm (trước đây lấy hiệu số năm dương lịch)
                int tenureYears = java.time.Period.between(e.getJoinDate(), date).getYears();
                if (tenureYears < (rule.getMinTenureYears() == null ? 0 : rule.getMinTenureYears())) continue;

                // Skip nếu đã cộng trong kỳ này
                boolean alreadyGranted = leaveGrantRepository.existsAccrualGrantForPeriod(
                    rule.getId(), e.getId(),
                    rule.getFrequency().name(),
                    date.getYear(), date.getMonthValue()
                );
                if (alreadyGranted) continue;

                LocalDate validFrom = rule.getValidFrom();
                LocalDate validTo = rule.getValidTo();
                if (rule.getExpireAfterDays() != null) {
                    validFrom = date;
                    validTo = date.plusDays(rule.getExpireAfterDays());
                }
                LeaveGrant grant = LeaveGrant.builder()
                    .company(company)
                    .employee(e)
                    .source(LeaveGrant.Source.AUTO)
                    .grantDays(rule.getGrantDays())
                    .grantHours(rule.getGrantHours())
                    .grantedAt(date)
                    .validFrom(validFrom)
                    .validTo(validTo)
                    .accrualRule(rule)
                    .note("Auto accrual")
                    .build();
                normalizeGrantAmount(grant, hoursPerDay);
                leaveGrantRepository.save(grant);
                created++;
            }
        }
        return Map.of("created", created);
    }

    /** Ngày cộng 29–31 ở tháng ngắn hơn thì cộng vào ngày cuối tháng. */
    private static boolean matchesDayOfMonth(Integer dayOfMonth, LocalDate date) {
        if (dayOfMonth == null) return false;
        int effective = Math.min(dayOfMonth, date.lengthOfMonth());
        return effective == date.getDayOfMonth();
    }

    private void validateRule(LeaveDTO.LeaveAccrualRuleUpsert req) {
        if (req.getFrequency() == LeaveAccrualRule.Frequency.MONTHLY) {
            if (req.getDayOfMonth() == null || req.getDayOfMonth() < 1 || req.getDayOfMonth() > 31) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.leave_rule.day_of_month_invalid");
            }
        }
        if (req.getFrequency() == LeaveAccrualRule.Frequency.YEARLY) {
            if (req.getDayOfMonth() == null || req.getDayOfMonth() < 1 || req.getDayOfMonth() > 31
                || req.getMonthOfYear() == null || req.getMonthOfYear() < 1 || req.getMonthOfYear() > 12) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.leave_rule.month_invalid");
            }
        }
        if (req.getValidFrom() != null && req.getValidTo() != null && req.getValidTo().isBefore(req.getValidFrom())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.leave.validity_invalid");
        }
    }

    private LeaveDTO.LeaveRequestResponse createGroupRequest(
        User user, Employee emp, LeaveType type,
        LeaveDTO.CreateLeaveRequest req, BigDecimal hpd, boolean isHourType
    ) {
        // Tính tổng amount toàn group để check balance trước
        // Ca đêm xuyên ngày (toTime < fromTime): số ca = toDate - fromDate (không +1)
        boolean isNightShift = req.getMode() == LeaveRequest.Mode.HOUR_RANGE
            && req.getFromTime() != null && req.getToTime() != null
            && req.getToTime().isBefore(req.getFromTime());
        long totalDays = java.time.temporal.ChronoUnit.DAYS.between(req.getFromDate(), req.getToDate()) + 1;
        BigDecimal amountPerDay;
        if (req.getMode() == LeaveRequest.Mode.HOUR_RANGE
                && req.getFromTime() != null && req.getToTime() != null) {
            // Số giờ mỗi ngày = khoảng fromTime→toTime
            long minutes = java.time.Duration.between(req.getFromTime(), req.getToTime()).toMinutes();
            if (minutes <= 0) {
                // Ca đêm xuyên ngày (vd 22:00→06:00): chỉ cho phép khi nhiều ngày
                if (req.getFromDate().equals(req.getToDate())) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.time.end_before_start");
                }
                minutes += 1440; // +24h
            }
            amountPerDay = BigDecimal.valueOf(minutes).divide(BigDecimal.valueOf(60), 2, RoundingMode.HALF_UP);
        } else {
            amountPerDay = isHourType ? hpd : BigDecimal.ONE;
        }
        BigDecimal totalAmount = amountPerDay.multiply(BigDecimal.valueOf(totalDays));

        List<LeaveGrant> usable = type.isRequiresBalance()
            ? leaveGrantRepository.findUsableGrantsForType(emp.getId(), type.getId(), req.getFromDate())
            : List.of();
        BigDecimal available = usable.stream()
            .map(g -> isHourType ? availableHours(g, hpd) : availableDays(g, hpd))
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        if (type.isRequiresBalance() && available.compareTo(totalAmount) < 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.leave.insufficient_balance");
        }

        // Tạo đơn cha (không trừ phép, chỉ là group)
        LeaveRequest parent = LeaveRequest.builder()
            .company(companyRef(user.getCompanyId()))
            .employee(emp)
            .leaveType(type)
            .mode(req.getMode())
            .fromDate(req.getFromDate())
            .toDate(req.getToDate())
            .fromTime(req.getFromTime())
            .toTime(req.getToTime())
            .requestedAmount(totalAmount)
            .reason(req.getReason())
            .build();
        parent = leaveRequestRepository.save(parent);

        // Trừ tổng phép 1 lần cho toàn group, ghi sổ theo đơn cha (L13)
        if (type.isRequiresBalance()) {
            deductWithLedger(parent, emp, isHourType, totalAmount, hpd);
        }

        // Tạo đơn con cho từng ngày/ca
        LocalDate loopEnd = req.getToDate();
        for (LocalDate d = req.getFromDate(); !d.isAfter(loopEnd); d = d.plusDays(1)) {
            LocalDate childToDate = isNightShift ? d.plusDays(1) : d;
            LeaveRequest child = LeaveRequest.builder()
                .company(companyRef(user.getCompanyId()))
                .employee(emp)
                .leaveType(type)
                .mode(req.getMode())
                .fromDate(d)
                .toDate(childToDate)
                .fromTime(req.getFromTime())
                .toTime(req.getToTime())
                .requestedAmount(amountPerDay)
                .reason(req.getReason())
                .parent(parent)
                .build();
            leaveRequestRepository.save(child);
        }

        return saveAndReload(parent, user.getCompanyId());
    }

    private BigDecimal calculateRequestedAmount(LeaveDTO.CreateLeaveRequest req, LeaveType type) {
        BigDecimal hoursPerDay = resolveHoursPerDay(type.getCompany());
        if (req.getMode() == LeaveRequest.Mode.DAY_RANGE) {
            long days = java.time.temporal.ChronoUnit.DAYS.between(req.getFromDate(), req.getToDate()) + 1;
            if (days <= 0) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.date.range_invalid");
            if (type.getUnit() == LeaveType.Unit.DAY) {
                return BigDecimal.valueOf(days);
            }
            return BigDecimal.valueOf(days).multiply(hoursPerDay).setScale(2, RoundingMode.HALF_UP);
        }
        if (req.getFromDate() == null || req.getToDate() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.date.range_invalid");
        }
        if (req.getFromTime() == null || req.getToTime() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.time.range_invalid");
        }
        var start = java.time.LocalDateTime.of(req.getFromDate(), req.getFromTime());
        var end = java.time.LocalDateTime.of(req.getToDate(), req.getToTime());
        if (!end.isAfter(start)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.time.range_invalid");
        }
        long minutes = java.time.Duration.between(start, end).toMinutes();
        return BigDecimal.valueOf(minutes).divide(BigDecimal.valueOf(60), 2, RoundingMode.HALF_UP);
    }

    private BigDecimal resolveHoursPerDay(Company company) {
        if (company == null || company.getId() == null) {
            return BigDecimal.valueOf(8);
        }
        Company c = companyRepository.findById(company.getId()).orElse(company);
        BigDecimal v = c.getLeaveHoursPerDay();
        if (v == null || v.compareTo(BigDecimal.ZERO) <= 0) {
            return BigDecimal.valueOf(8);
        }
        return v;
    }

    private List<LeaveRequest> filterByLeaveViewScope(List<LeaveRequest> requests, User user, Set<Long> selectedDeptScope) {
        if (requests == null || requests.isEmpty()) return List.of();
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "LEAVE_VIEW");
        boolean selfOnly = scope.contains(DeptScopeService.SCOPE_SELF_ONLY);
        Set<Long> deptScope = scope.stream().filter(id -> id > 0).collect(Collectors.toSet());
        Long myEmpId = selfOnly ? employeeRepository.findByUserIdFetch(user.getId())
            .map(Employee::getId).orElse(null) : null;
        return requests.stream()
            .filter(r -> r.getEmployee() != null)
            .filter(r -> {
                if (selfOnly) return myEmpId != null && myEmpId.equals(r.getEmployee().getId());
                if (deptScope.isEmpty()) return true;
                return r.getEmployee().getDepartment() != null
                    && deptScope.contains(r.getEmployee().getDepartment().getId());
            })
            .filter(r -> selectedDeptScope == null
                || (r.getEmployee().getDepartment() != null
                    && selectedDeptScope.contains(r.getEmployee().getDepartment().getId())))
            .toList();
    }

    /** L13 — sổ trừ/hoàn phép của một nhân viên (mới nhất trước). Nhân viên luôn xem được sổ của mình. */
    @Transactional(readOnly = true)
    public List<LeaveDTO.LedgerEntryResponse> getLedger(User user, Long employeeId) {
        Employee emp = employeeRepository.findByIdAndCompanyId(employeeId, user.getCompanyId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
        boolean self = user.getEmployeeId() != null && user.getEmployeeId().equals(emp.getId());
        if (!self) {
            requirePermission(user, "LEAVE_VIEW");
            requireLeaveViewScope(user, emp);
        }
        return ledgerRepository.findByEmployee(user.getCompanyId(), emp.getId()).stream()
            .map(e -> LeaveDTO.LedgerEntryResponse.builder()
                .id(e.getId())
                .kind(e.getKind().name())
                .grantId(e.getGrant().getId())
                .grantLeaveTypeName(e.getGrant().getLeaveType() != null ? e.getGrant().getLeaveType().getName() : null)
                .grantedAt(e.getGrant().getGrantedAt())
                .requestId(e.getRequest().getId())
                .requestLeaveTypeName(e.getRequest().getLeaveType().getName())
                .requestFromDate(e.getRequest().getFromDate())
                .requestToDate(e.getRequest().getToDate())
                .days(e.getDays())
                .hours(e.getHours())
                .createdAt(e.getCreatedAt())
                .build())
            .toList();
    }

    private void requireLeaveViewScope(User user, Employee employee) {
        if (employee == null || employee.getDepartment() == null) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "LEAVE_VIEW");
        if (!scope.isEmpty() && !scope.contains(employee.getDepartment().getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }

    private boolean isManager(User user) {
        return user.hasPermission("LEAVE_REQUEST_APPROVE") || user.hasPermission("LEAVE_ACCRUAL_MANAGE") || user.hasPermission("LEAVE_GRANT_MANUAL");
    }

    private void requirePermission(User user, String perm) {
        if (user == null || !user.hasPermission(perm)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }

    private Employee getEmployeeOrThrow(User user) {
        return employeeRepository.findByUserIdFetch(user.getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.user.employee_not_linked"));
    }

    private LeaveRequest getRequestOrThrow(Long id, Long companyId) {
        return leaveRequestRepository.findByIdAndCompanyId(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.request.not_found"));
    }

    private LeaveDTO.LeaveRequestResponse saveAndReload(LeaveRequest request, Long companyId) {
        leaveRequestRepository.save(request);
        entityManager.flush();
        entityManager.detach(request);
        return toLeaveRequestResponse(getRequestOrThrow(request.getId(), companyId));
    }

    private LeaveDTO.LeaveTypeResponse toLeaveTypeResponse(LeaveType t) {
        return LeaveDTO.LeaveTypeResponse.builder()
            .id(t.getId()).code(t.getCode()).name(t.getName())
            .unit(t.getUnit()).deductPerDay(t.getDeductPerDay()).paid(t.isPaid()).requiresBalance(t.isRequiresBalance()).active(t.isActive())
            .description(t.getDescription())
            .build();
    }

    private BigDecimal normalizeDeductPerDay(LeaveType.Unit unit, BigDecimal value) {
        if (unit == LeaveType.Unit.HOUR) {
            return BigDecimal.ONE.setScale(2, RoundingMode.HALF_UP);
        }
        if (value == null || value.compareTo(BigDecimal.ZERO) <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.leave_type.deduct_per_day_invalid");
        }
        return value.setScale(2, RoundingMode.HALF_UP);
    }

    private LeaveDTO.LeaveGrantResponse toLeaveGrantResponse(LeaveGrant g) {
        Employee e = g.getEmployee();
        LeaveType t = g.getLeaveType();
        return LeaveDTO.LeaveGrantResponse.builder()
            .id(g.getId())
            .employeeId(e.getId())
            .employeeCode(e.getEmployeeCode())
            .employeeName(e.getFullName())
            .departmentId(e.getDepartment() != null ? e.getDepartment().getId() : null)
            .departmentName(e.getDepartment() != null ? e.getDepartment().getName() : null)
            .leaveTypeId(t != null ? t.getId() : null)
            .leaveTypeName(t != null ? t.getName() : null)
            .leaveUnit(t != null ? t.getUnit() : null)
            .source(g.getSource())
            .grantDays(g.getGrantDays())
            .grantHours(g.getGrantHours())
            .usedDays(g.getUsedDays())
            .usedHours(g.getUsedHours())
            .remainingDays(computeRemainingDays(g))
            .remainingHours(computeRemainingHours(g))
            .grantedAt(g.getGrantedAt())
            .validFrom(g.getValidFrom())
            .validTo(g.getValidTo())
            .note(g.getNote())
            .build();
    }

    private LeaveDTO.LeaveRequestResponse toLeaveRequestResponse(LeaveRequest r) {
        Employee e = r.getEmployee();
        LeaveType t = r.getLeaveType();
        return LeaveDTO.LeaveRequestResponse.builder()
            .id(r.getId())
            .employeeId(e.getId())
            .employeeCode(e.getEmployeeCode())
            .employeeName(e.getFullName())
            .departmentId(e.getDepartment() != null ? e.getDepartment().getId() : null)
            .departmentName(e.getDepartment() != null ? e.getDepartment().getName() : null)
            .leaveTypeId(t.getId())
            .leaveTypeName(t.getName())
            .leaveUnit(t.getUnit())
            .mode(r.getMode())
            .fromDate(r.getFromDate())
            .toDate(r.getToDate())
            .fromTime(r.getFromTime())
            .toTime(r.getToTime())
            .requestedAmount(r.getRequestedAmount())
            .status(r.getStatus())
            .applied(r.isApplied())
            .reason(r.getReason())
            .adminNote(r.getAdminNote())
            .processedByName(r.getProcessedBy() != null && r.getProcessedBy().getEmployee() != null
                ? r.getProcessedBy().getEmployee().getFullName() : null)
            .createdAt(r.getCreatedAt())
            .processedAt(r.getProcessedAt())
            .parentId(r.getParent() != null ? r.getParent().getId() : null)
            .children(r.getChildren() == null || r.getChildren().isEmpty() ? List.of()
                : r.getChildren().stream().map(this::toLeaveRequestChildResponse).toList())
            .build();
    }

    private LeaveDTO.LeaveRequestResponse toLeaveRequestChildResponse(LeaveRequest r) {
        Employee e = r.getEmployee();
        LeaveType t = r.getLeaveType();
        return LeaveDTO.LeaveRequestResponse.builder()
            .id(r.getId())
            .employeeId(e.getId())
            .leaveTypeId(t.getId())
            .leaveTypeName(t.getName())
            .leaveUnit(t.getUnit())
            .mode(r.getMode())
            .fromDate(r.getFromDate())
            .toDate(r.getToDate())
            .requestedAmount(r.getRequestedAmount())
            .status(r.getStatus())
            .applied(r.isApplied())
            .parentId(r.getParent() != null ? r.getParent().getId() : null)
            .children(List.of())
            .build();
    }

    private LeaveDTO.LeaveAccrualRuleResponse toRuleResponse(LeaveAccrualRule rule) {
        return LeaveDTO.LeaveAccrualRuleResponse.builder()
            .id(rule.getId())
            .name(rule.getName())
            .departmentId(rule.getDepartment() != null ? rule.getDepartment().getId() : null)
            .departmentName(rule.getDepartment() != null ? rule.getDepartment().getName() : null)
            .grantDays(rule.getGrantDays())
            .grantHours(rule.getGrantHours())
            .frequency(rule.getFrequency())
            .dayOfMonth(rule.getDayOfMonth())
            .monthOfYear(rule.getMonthOfYear())
            .minTenureYears(rule.getMinTenureYears())
            .validFrom(rule.getValidFrom())
            .validTo(rule.getValidTo())
            .expireAfterDays(rule.getExpireAfterDays())
            .active(rule.isActive())
            .build();
    }

    /**
     * L13 — trừ phép trên các quỹ dùng được của loại phép và ghi sổ từng quỹ đã đổi.
     * {@code source} là đơn gốc (đơn lẻ hoặc đơn cha của nhóm).
     */
    private void deductWithLedger(LeaveRequest source, Employee emp, boolean isHourType,
                                  BigDecimal amount, BigDecimal hpd) {
        List<LeaveGrant> usable = leaveGrantRepository.findUsableGrantsForType(
            emp.getId(), source.getLeaveType().getId(), source.getFromDate());
        BigDecimal remaining = amount;
        List<LeaveLedgerEntry> entries = new ArrayList<>();
        for (LeaveGrant g : usable) {
            if (remaining.compareTo(BigDecimal.ZERO) <= 0) break;
            BigDecimal d0 = g.getUsedDays(), h0 = g.getUsedHours();
            remaining = isHourType ? deductHours(g, remaining, hpd) : deductDays(g, remaining, hpd);
            BigDecimal dd = g.getUsedDays().subtract(d0), dh = g.getUsedHours().subtract(h0);
            if (dd.signum() != 0 || dh.signum() != 0) {
                entries.add(LeaveLedgerEntry.builder()
                    .companyId(emp.getCompany().getId()).employeeId(emp.getId())
                    .grant(g).request(source).kind(LeaveLedgerEntry.Kind.DEDUCT)
                    .days(dd).hours(dh).build());
            }
        }
        leaveGrantRepository.saveAll(usable);
        ledgerRepository.saveAll(entries);
    }

    /**
     * L13 — hoàn phép theo sổ: đảo ngược đúng các quỹ mà đơn gốc đã trừ (quỹ trừ sau hoàn trước).
     * Trả false nếu đơn không có dòng sổ (đơn tạo trước V8) để dùng cách hoàn cũ.
     */
    private boolean refundFromLedger(LeaveRequest request, BigDecimal amount, boolean isHour, BigDecimal hpd) {
        LeaveRequest source = request.getParent() != null ? request.getParent() : request;
        List<LeaveLedgerEntry> entries = ledgerRepository.findByRequestIdFetchGrant(source.getId());
        if (entries.isEmpty()) return false;

        // Phần còn trừ (chưa hoàn) trên từng quỹ, giữ thứ tự quỹ được trừ
        Map<Long, BigDecimal[]> net = new LinkedHashMap<>();
        Map<Long, LeaveGrant> grants = new HashMap<>();
        for (LeaveLedgerEntry e : entries) {
            BigDecimal[] n = net.computeIfAbsent(e.getGrant().getId(), k -> new BigDecimal[]{BigDecimal.ZERO, BigDecimal.ZERO});
            int sign = e.getKind() == LeaveLedgerEntry.Kind.DEDUCT ? 1 : -1;
            n[0] = n[0].add(e.getDays().multiply(BigDecimal.valueOf(sign)));
            n[1] = n[1].add(e.getHours().multiply(BigDecimal.valueOf(sign)));
            grants.put(e.getGrant().getId(), e.getGrant());
        }
        List<Long> order = new ArrayList<>(net.keySet());
        Collections.reverse(order);

        BigDecimal remainingH = isHour ? amount : amount.multiply(hpd);
        List<LeaveLedgerEntry> refunds = new ArrayList<>();
        for (Long gid : order) {
            if (remainingH.signum() <= 0) break;
            BigDecimal[] n = net.get(gid);
            BigDecimal netH = n[0].multiply(hpd).add(n[1]);
            if (netH.signum() <= 0) continue;
            LeaveGrant g = grants.get(gid);
            BigDecimal rd, rh;
            if (remainingH.compareTo(netH) >= 0) {
                rd = n[0]; rh = n[1];
                remainingH = remainingH.subtract(netH);
            } else {
                BigDecimal f = remainingH.divide(netH, 8, RoundingMode.HALF_UP);
                rd = n[0].multiply(f).setScale(4, RoundingMode.HALF_UP);
                rh = n[1].multiply(f).setScale(4, RoundingMode.HALF_UP);
                remainingH = BigDecimal.ZERO;
            }
            BigDecimal d0 = g.getUsedDays(), h0 = g.getUsedHours();
            applyRefund(g, rd, rh, hpd);
            refunds.add(LeaveLedgerEntry.builder()
                .companyId(source.getCompany().getId()).employeeId(source.getEmployee().getId())
                .grant(g).request(source).kind(LeaveLedgerEntry.Kind.REFUND)
                .days(d0.subtract(g.getUsedDays())).hours(h0.subtract(g.getUsedHours())).build());
        }
        leaveGrantRepository.saveAll(grants.values());
        ledgerRepository.saveAll(refunds);
        return true;
    }

    /** Trừ lại usedDays/usedHours; ngày lẻ chuyển sang giờ theo quy ước của deductHours. */
    private static void applyRefund(LeaveGrant g, BigDecimal days, BigDecimal hours, BigDecimal hpd) {
        BigDecimal d = g.getUsedDays().subtract(days);
        BigDecimal h = g.getUsedHours().subtract(hours);
        BigDecimal frac = d.subtract(d.setScale(0, RoundingMode.FLOOR));
        boolean wasWhole = g.getUsedDays().stripTrailingZeros().scale() <= 0;
        if (h.signum() < 0 || (wasWhole && frac.signum() != 0)) {
            BigDecimal total = d.multiply(hpd).add(h).max(BigDecimal.ZERO);
            d = total.divideToIntegralValue(hpd);
            h = total.subtract(d.multiply(hpd));
        }
        g.setUsedDays(d.max(BigDecimal.ZERO).setScale(2, RoundingMode.HALF_UP));
        g.setUsedHours(h.max(BigDecimal.ZERO).setScale(2, RoundingMode.HALF_UP));
    }

    /** Hoàn lại phép khi request bị hủy/từ chối. */
    private void refundBalance(LeaveRequest request, BigDecimal hpd) {
        if (request.getLeaveType() != null && !request.getLeaveType().isRequiresBalance()) return; // L8
        boolean isHour = request.getLeaveType() != null
            && request.getLeaveType().getUnit() == LeaveType.Unit.HOUR;
        BigDecimal amount = request.getRequestedAmount();
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) return;
        if (refundFromLedger(request, amount, isHour, hpd)) return;

        // Lấy các grant đã trừ (ngược chiều deduct: DESC)
        List<LeaveGrant> grants = leaveGrantRepository.findUsableGrantsForRefund(
            request.getEmployee().getId(), request.getFromDate());

        BigDecimal remaining = amount;
        for (LeaveGrant g : grants) {
            if (remaining.compareTo(BigDecimal.ZERO) <= 0) break;
            if (isHour) {
                // Hoàn giờ lẻ trước (usedHours)
                BigDecimal refundH = g.getUsedHours().min(remaining);
                g.setUsedHours(g.getUsedHours().subtract(refundH));
                remaining = remaining.subtract(refundH);
                // Còn thiếu → hoàn ngày nguyên (usedDays)
                if (remaining.compareTo(BigDecimal.ZERO) > 0) {
                    BigDecimal wholeDays = remaining.divideToIntegralValue(hpd).min(g.getUsedDays());
                    if (wholeDays.compareTo(BigDecimal.ZERO) > 0) {
                        g.setUsedDays(g.getUsedDays().subtract(wholeDays));
                        remaining = remaining.subtract(wholeDays.multiply(hpd));
                    }
                    // Giờ lẻ còn lại sau khi hoàn ngày
                    if (remaining.compareTo(BigDecimal.ZERO) > 0 && g.getUsedDays().compareTo(BigDecimal.ZERO) > 0) {
                        g.setUsedDays(g.getUsedDays().subtract(BigDecimal.ONE));
                        BigDecimal unusedInDay = hpd.subtract(remaining);
                        g.setUsedHours(g.getUsedHours().add(unusedInDay).max(BigDecimal.ZERO));
                        remaining = BigDecimal.ZERO;
                    }
                }
            } else {
                BigDecimal refund = g.getUsedDays().min(remaining);
                g.setUsedDays(g.getUsedDays().subtract(refund));
                remaining = remaining.subtract(refund);
                // Nếu còn thiếu → hoàn từ usedHours đã mượn
                if (remaining.compareTo(BigDecimal.ZERO) > 0) {
                    BigDecimal hourRefund = g.getUsedHours().min(remaining.multiply(hpd));
                    g.setUsedHours(g.getUsedHours().subtract(hourRefund));
                    remaining = remaining.subtract(hourRefund.divide(hpd, 4, java.math.RoundingMode.HALF_UP));
                }
            }
        }
        leaveGrantRepository.saveAll(grants);
    }

    /** Tổng giờ còn lại của grant (bao gồm quy đổi từ ngày). */
    private BigDecimal availableHours(LeaveGrant g, BigDecimal hpd) {
        BigDecimal hours = g.getGrantHours() != null
            ? g.getGrantHours().subtract(g.getUsedHours()) : BigDecimal.ZERO;
        BigDecimal days = g.getGrantDays() != null
            ? g.getGrantDays().subtract(g.getUsedDays()) : BigDecimal.ZERO;
        return hours.add(days.multiply(hpd)).max(BigDecimal.ZERO);
    }

    /** Tổng ngày còn lại của grant (bao gồm quy đổi từ giờ). */
    private BigDecimal availableDays(LeaveGrant g, BigDecimal hpd) {
        BigDecimal days = g.getGrantDays() != null
            ? g.getGrantDays().subtract(g.getUsedDays()) : BigDecimal.ZERO;
        BigDecimal hours = g.getGrantHours() != null
            ? g.getGrantHours().subtract(g.getUsedHours()) : BigDecimal.ZERO;
        return days.add(hours.divide(hpd, 4, java.math.RoundingMode.HALF_UP)).max(BigDecimal.ZERO);
    }

    /**
     * Trừ giờ từ grant.
     * Quy ước: usedDays = số ngày nguyên đã dùng hết, usedHours = giờ lẻ chưa đủ 1 ngày.
     * Ví dụ: 42h / 8hpd = usedDays=5, usedHours=2.
     * Trả về số giờ còn thiếu sau khi trừ (0 = đủ).
     */
    private BigDecimal deductHours(LeaveGrant g, BigDecimal needed, BigDecimal hpd) {
        BigDecimal grantH = g.getGrantHours() != null ? g.getGrantHours() : BigDecimal.ZERO;
        BigDecimal grantD = g.getGrantDays() != null ? g.getGrantDays() : BigDecimal.ZERO;

        // Tổng giờ đã dùng = usedDays*hpd + usedHours
        BigDecimal totalUsed = g.getUsedDays().multiply(hpd).add(g.getUsedHours());
        // Tổng giờ grant
        BigDecimal totalGrant = grantD.multiply(hpd).add(grantH);
        BigDecimal totalAvail = totalGrant.subtract(totalUsed).max(BigDecimal.ZERO);

        BigDecimal consume = needed.min(totalAvail);
        if (consume.compareTo(BigDecimal.ZERO) <= 0) return needed;

        BigDecimal newTotalUsed = totalUsed.add(consume);
        g.setUsedDays(newTotalUsed.divideToIntegralValue(hpd));
        g.setUsedHours(newTotalUsed.remainder(hpd));

        return needed.subtract(consume);
    }

    /**
     * Trừ ngày từ grant. Khi hết ngày, quy đổi giờ → ngày nếu còn giờ.
     * Trả về số ngày còn thiếu sau khi trừ (0 = đủ).
     */
    private BigDecimal deductDays(LeaveGrant g, BigDecimal needed, BigDecimal hpd) {
        BigDecimal availD = g.getGrantDays() != null
            ? g.getGrantDays().subtract(g.getUsedDays()) : BigDecimal.ZERO;
        if (availD.compareTo(BigDecimal.ZERO) > 0) {
            BigDecimal consume = availD.min(needed);
            g.setUsedDays(g.getUsedDays().add(consume));
            needed = needed.subtract(consume);
        }
        // Hết ngày → mượn từ giờ (không mutate grantDays)
        while (needed.compareTo(BigDecimal.ZERO) > 0) {
            BigDecimal availH = g.getGrantHours() != null
                ? g.getGrantHours().subtract(g.getUsedHours()) : BigDecimal.ZERO;
            if (availH.compareTo(hpd) < 0) break;
            // L14: mượn giờ chỉ tăng usedHours (trước đây cộng cả usedDays → trừ 2 lần)
            g.setUsedHours(g.getUsedHours().add(hpd));
            BigDecimal consume = BigDecimal.ONE.min(needed);
            needed = needed.subtract(consume);
        }
        return needed;
    }

    private BigDecimal loadHoursPerDay(Long companyId) {
        return companyRepository.findById(companyId)
            .map(Company::getLeaveHoursPerDay)
            .filter(h -> h != null && h.compareTo(BigDecimal.ZERO) > 0)
            .orElse(BigDecimal.valueOf(8));
    }

    private Company companyRef(Long id) {
        Company c = new Company();
        c.setId(id);
        return c;
    }

    private BigDecimal computeRemainingDays(LeaveGrant g) {
        if (g.getGrantDays() == null) return null;
        // usedHours > 0 nghĩa là ngày đó chưa dùng hết → còn lại = grantDays - usedDays - 1 ngày dở
        BigDecimal rem = g.getGrantDays().subtract(g.getUsedDays());
        if (g.getUsedHours().compareTo(BigDecimal.ZERO) > 0) {
            rem = rem.subtract(BigDecimal.ONE);
        }
        return rem;
    }

    private BigDecimal computeRemainingHours(LeaveGrant g) {
        BigDecimal hpd = loadHoursPerDay(g.getCompany().getId());
        BigDecimal grantH = g.getGrantHours() != null ? g.getGrantHours() : BigDecimal.ZERO;
        if (g.getGrantDays() == null && grantH.compareTo(BigDecimal.ZERO) == 0) return null;

        // Tổng giờ còn lại = totalGrant - totalUsed, lấy phần lẻ < hpd
        BigDecimal grantD = g.getGrantDays() != null ? g.getGrantDays() : BigDecimal.ZERO;
        BigDecimal totalGrant = grantD.multiply(hpd).add(grantH);
        BigDecimal totalUsed = g.getUsedDays().multiply(hpd).add(g.getUsedHours());
        BigDecimal totalRem = totalGrant.subtract(totalUsed).max(BigDecimal.ZERO);
        BigDecimal remH = totalRem.remainder(hpd);
        return remH.compareTo(BigDecimal.ZERO) == 0 ? null : remH;
    }

    /** Quy đổi phần giờ >= hoursPerDay thành ngày, cộng thẳng vào grantDays. */
    private void normalizeGrantAmount(LeaveGrant grant, BigDecimal hpd) {
        if (hpd == null || hpd.compareTo(BigDecimal.ZERO) <= 0) return;
        BigDecimal hours = grant.getGrantHours();
        if (hours == null || hours.compareTo(hpd) < 0) return;
        BigDecimal extraDays = hours.divideToIntegralValue(hpd);
        BigDecimal remainHours = hours.remainder(hpd);
        grant.setGrantDays((grant.getGrantDays() != null ? grant.getGrantDays() : BigDecimal.ZERO)
            .add(extraDays).setScale(2, RoundingMode.HALF_UP));
        grant.setGrantHours(remainHours.setScale(2, RoundingMode.HALF_UP));
    }

    /**
     * L11: không cho 2 đơn nghỉ (đang chờ hoặc đã duyệt) chồng ngày của cùng nhân viên.
     * Hai đơn theo giờ trong cùng một ngày được phép nếu khung giờ không giao nhau.
     */
    private void requireNoOverlap(Long employeeId, LeaveDTO.CreateLeaveRequest req) {
        for (LeaveRequest other : leaveRequestRepository.findByEmployeeIdOrderByCreatedAtDesc(employeeId)) {
            if (other.getStatus() != LeaveRequest.Status.PENDING && other.getStatus() != LeaveRequest.Status.APPROVED) continue;
            if (other.getFromDate().isAfter(req.getToDate()) || other.getToDate().isBefore(req.getFromDate())) continue;
            boolean bothHourSameDay = other.getMode() == LeaveRequest.Mode.HOUR_RANGE
                && req.getMode() == LeaveRequest.Mode.HOUR_RANGE
                && other.getFromDate().equals(other.getToDate()) && req.getFromDate().equals(req.getToDate())
                && other.getFromTime() != null && other.getToTime() != null
                && req.getFromTime() != null && req.getToTime() != null;
            if (bothHourSameDay && (!other.getFromTime().isBefore(req.getToTime())
                    || !req.getFromTime().isBefore(other.getToTime()))) {
                continue; // khung giờ không giao nhau
            }
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.leave.overlap");
        }
    }
}
