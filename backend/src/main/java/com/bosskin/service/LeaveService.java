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
    private final LeaveGrantRepository leaveGrantRepository;
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
        if (leaveTypeRepository.existsByCompanyIdAndCodeIgnoreCase(companyId, req.getCode())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Mã loại phép đã tồn tại");
        }
        LeaveType type = LeaveType.builder()
            .company(companyRef(companyId))
            .code(req.getCode().trim().toUpperCase())
            .name(req.getName().trim())
            .unit(req.getUnit())
            .deductPerDay(normalizeDeductPerDay(req.getUnit(), req.getDeductPerDay()))
            .paid(Boolean.TRUE.equals(req.getPaid()))
            .active(Boolean.TRUE.equals(req.getActive()))
            .description(req.getDescription())
            .build();
        return toLeaveTypeResponse(leaveTypeRepository.save(type));
    }

    @Transactional
    public LeaveDTO.LeaveTypeResponse updateType(Long companyId, Long id, LeaveDTO.LeaveTypeUpsert req) {
        LeaveType type = leaveTypeRepository.findByIdAndCompanyIdAndDeletedFalse(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy loại phép"));
        if (leaveTypeRepository.existsByCompanyIdAndCodeIgnoreCaseAndIdNot(companyId, req.getCode(), id)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Mã loại phép đã tồn tại");
        }
        type.setCode(req.getCode().trim().toUpperCase());
        type.setName(req.getName().trim());
        type.setUnit(req.getUnit());
        type.setDeductPerDay(normalizeDeductPerDay(req.getUnit(), req.getDeductPerDay()));
        type.setPaid(Boolean.TRUE.equals(req.getPaid()));
        type.setActive(Boolean.TRUE.equals(req.getActive()));
        type.setDescription(req.getDescription());
        return toLeaveTypeResponse(leaveTypeRepository.save(type));
    }

    @Transactional
    public void deleteType(Long companyId, Long id) {
        LeaveType type = leaveTypeRepository.findByIdAndCompanyIdAndDeletedFalse(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy loại phép"));
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

    @Transactional
    public LeaveDTO.LeaveRequestResponse createRequest(User user, LeaveDTO.CreateLeaveRequest req) {
        Employee emp;
        if (req.getEmployeeId() != null) {
            emp = employeeRepository.findByIdAndCompanyId(req.getEmployeeId(), user.getCompanyId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy nhân viên"));
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
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy loại phép"));
        if (!type.isActive()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Loại phép đã ngưng sử dụng");
        }

        if (req.getToDate().isBefore(req.getFromDate())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Khoảng ngày không hợp lệ");
        }
        BigDecimal hpdReq = loadHoursPerDay(user.getCompanyId());
        boolean isHourType = type.getUnit() == LeaveType.Unit.HOUR;
        boolean isMultiDay = !req.getFromDate().equals(req.getToDate());

        if (isMultiDay) {
            return createGroupRequest(user, emp, type, req, hpdReq, isHourType);
        }

        BigDecimal requestedAmount = calculateRequestedAmount(req, type);
        List<LeaveGrant> usable = leaveGrantRepository.findUsableGrants(emp.getId(), null, req.getFromDate());
        BigDecimal available = usable.stream()
            .map(g -> isHourType ? availableHours(g, hpdReq) : availableDays(g, hpdReq))
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        if (available.compareTo(requestedAmount) < 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Số dư phép không đủ");
        }
        BigDecimal remainingNeed = requestedAmount;
        for (LeaveGrant grant : usable) {
            if (remainingNeed.compareTo(BigDecimal.ZERO) <= 0) break;
            remainingNeed = isHourType
                ? deductHours(grant, remainingNeed, hpdReq)
                : deductDays(grant, remainingNeed, hpdReq);
        }
        leaveGrantRepository.saveAll(usable);

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
        return saveAndReload(request, user.getCompanyId());
    }

    @Transactional
    public LeaveDTO.LeaveRequestResponse approveRequest(Long id, User admin, LeaveDTO.ProcessLeaveRequest body) {
        requirePermission(admin, "LEAVE_REQUEST_APPROVE");
        Long companyId = admin.getCompanyId();
        LeaveRequest request = getRequestOrThrow(id, companyId);
        requireLeaveViewScope(admin, request.getEmployee());
        if (request.getStatus() != LeaveRequest.Status.PENDING) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Chỉ duyệt yêu cầu đang chờ");
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
        requireLeaveViewScope(admin, request.getEmployee());
        if (request.getStatus() != LeaveRequest.Status.PENDING) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Chỉ từ chối yêu cầu đang chờ");
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
        boolean isAdmin = user.getRoles().stream()
            .anyMatch(r -> r.getName().equals("ADMIN") || r.getName().equals("HR"));
        boolean isOwner = user.getEmployeeId() != null
            && user.getEmployeeId().equals(request.getEmployee().getId());
        if (!isAdmin && !isOwner) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền hủy yêu cầu này");
        }
        if (request.getStatus() == LeaveRequest.Status.CANCELLED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Yêu cầu đã được hủy");
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
        requireLeaveViewScope(admin, request.getEmployee());
        if (request.getStatus() != LeaveRequest.Status.APPROVED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Chỉ đổi áp dụng cho yêu cầu đã duyệt");
        }
        request.setApplied(applied);
        return saveAndReload(request, companyId);
    }

    @Transactional
    public LeaveDTO.LeaveGrantResponse createManualGrant(User admin, LeaveDTO.ManualGrantRequest req) {
        requirePermission(admin, "LEAVE_GRANT_MANUAL");
        Long companyId = admin.getCompanyId();
        Employee employee = employeeRepository.findByIdAndCompanyId(req.getEmployeeId(), companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy nhân viên"));
        requireLeaveViewScope(admin, employee);
        LeaveType leaveType = null;
        if (req.getLeaveTypeId() != null) {
            leaveType = leaveTypeRepository.findByIdAndCompanyIdAndDeletedFalse(req.getLeaveTypeId(), companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy loại phép"));
        }

        if (req.getGrantDays() == null && req.getGrantHours() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Phải nhập số ngày hoặc số giờ");
        }
        LocalDate grantedAt = req.getGrantedAt() != null ? req.getGrantedAt() : LocalDate.now();
        LocalDate validFrom = req.getValidFrom();
        LocalDate validTo = req.getValidTo();
        if (req.getExpireAfterDays() != null) {
            validFrom = validFrom != null ? validFrom : grantedAt;
            validTo = validFrom.plusDays(req.getExpireAfterDays());
        }
        if (validFrom != null && validTo != null && validTo.isBefore(validFrom)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Khoảng hiệu lực không hợp lệ");
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
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy công ty"));
        return LeaveDTO.LeaveSettingResponse.builder()
            .leaveHoursPerDay(c.getLeaveHoursPerDay())
            .build();
    }

    @Transactional
    public LeaveDTO.LeaveSettingResponse updateSetting(Long companyId, LeaveDTO.LeaveSettingUpsert req) {
        Company c = companyRepository.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy công ty"));
        if (req.getLeaveHoursPerDay() == null || req.getLeaveHoursPerDay().compareTo(BigDecimal.ZERO) <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Số giờ mỗi ngày phải > 0");
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
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy phòng ban"));
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
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy rule"));
        Department department = null;
        if (req.getDepartmentId() != null) {
            department = departmentRepository.findByIdAndCompanyId(req.getDepartmentId(), companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy phòng ban"));
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
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy rule"));
        rule.setDeleted(true);
        rule.setActive(false);
        leaveAccrualRuleRepository.save(rule);
    }

    @Transactional
    public Map<String, Integer> runAccrual(User user, LocalDate runDate) {
        requirePermission(user, "LEAVE_ACCRUAL_MANAGE");
        LocalDate date = runDate != null ? runDate : LocalDate.now();
        Long companyId = user.getCompanyId();
        Company company = companyRepository.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy công ty"));
        BigDecimal hoursPerDay = company.getLeaveHoursPerDay() != null && company.getLeaveHoursPerDay().compareTo(BigDecimal.ZERO) > 0
            ? company.getLeaveHoursPerDay() : BigDecimal.valueOf(8);
        List<LeaveAccrualRule> rules = leaveAccrualRuleRepository.findByCompanyIdAndDeletedFalseOrderByCreatedAtDesc(companyId)
            .stream().filter(LeaveAccrualRule::isActive).toList();
        List<Employee> employees = employeeRepository.findByCompanyId(companyId);
        int created = 0;

        for (LeaveAccrualRule rule : rules) {
            boolean ruleMatches = switch (rule.getFrequency()) {
                case MONTHLY -> rule.getDayOfMonth() != null && rule.getDayOfMonth().equals(date.getDayOfMonth());
                case YEARLY -> rule.getDayOfMonth() != null && rule.getMonthOfYear() != null
                    && rule.getDayOfMonth().equals(date.getDayOfMonth())
                    && rule.getMonthOfYear().equals(date.getMonthValue());
            };
            if (!ruleMatches) continue;

            for (Employee e : employees) {
                if (rule.getDepartment() != null &&
                    (e.getDepartment() == null || !rule.getDepartment().getId().equals(e.getDepartment().getId()))) {
                    continue;
                }
                if (e.getJoinDate() == null) continue;
                int tenureYears = date.getYear() - e.getJoinDate().getYear();
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

    private void validateRule(LeaveDTO.LeaveAccrualRuleUpsert req) {
        if (req.getFrequency() == LeaveAccrualRule.Frequency.MONTHLY) {
            if (req.getDayOfMonth() == null || req.getDayOfMonth() < 1 || req.getDayOfMonth() > 31) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Day of month không hợp lệ");
            }
        }
        if (req.getFrequency() == LeaveAccrualRule.Frequency.YEARLY) {
            if (req.getDayOfMonth() == null || req.getDayOfMonth() < 1 || req.getDayOfMonth() > 31
                || req.getMonthOfYear() == null || req.getMonthOfYear() < 1 || req.getMonthOfYear() > 12) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Mốc năm không hợp lệ");
            }
        }
        if (req.getValidFrom() != null && req.getValidTo() != null && req.getValidTo().isBefore(req.getValidFrom())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Khoảng hiệu lực không hợp lệ");
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
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Giờ kết thúc phải sau giờ bắt đầu");
                }
                minutes += 1440; // +24h
            }
            amountPerDay = BigDecimal.valueOf(minutes).divide(BigDecimal.valueOf(60), 2, RoundingMode.HALF_UP);
        } else {
            amountPerDay = isHourType ? hpd : BigDecimal.ONE;
        }
        BigDecimal totalAmount = amountPerDay.multiply(BigDecimal.valueOf(totalDays));

        List<LeaveGrant> usable = leaveGrantRepository.findUsableGrants(emp.getId(), null, req.getFromDate());
        BigDecimal available = usable.stream()
            .map(g -> isHourType ? availableHours(g, hpd) : availableDays(g, hpd))
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        if (available.compareTo(totalAmount) < 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Số dư phép không đủ");
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

        // Trừ tổng phép 1 lần cho toàn group
        BigDecimal remaining = totalAmount;
        for (LeaveGrant g : usable) {
            if (remaining.compareTo(BigDecimal.ZERO) <= 0) break;
            remaining = isHourType ? deductHours(g, remaining, hpd) : deductDays(g, remaining, hpd);
        }
        leaveGrantRepository.saveAll(usable);

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
            if (days <= 0) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Khoảng ngày không hợp lệ");
            if (type.getUnit() == LeaveType.Unit.DAY) {
                return BigDecimal.valueOf(days);
            }
            return BigDecimal.valueOf(days).multiply(hoursPerDay).setScale(2, RoundingMode.HALF_UP);
        }
        if (req.getFromDate() == null || req.getToDate() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Khoảng ngày không hợp lệ");
        }
        if (req.getFromTime() == null || req.getToTime() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Khoảng giờ không hợp lệ");
        }
        var start = java.time.LocalDateTime.of(req.getFromDate(), req.getFromTime());
        var end = java.time.LocalDateTime.of(req.getToDate(), req.getToTime());
        if (!end.isAfter(start)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Khoảng giờ không hợp lệ");
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
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Tài khoản chưa được liên kết với nhân viên nào"));
    }

    private LeaveRequest getRequestOrThrow(Long id, Long companyId) {
        return leaveRequestRepository.findByIdAndCompanyId(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy yêu cầu"));
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
            .unit(t.getUnit()).deductPerDay(t.getDeductPerDay()).paid(t.isPaid()).active(t.isActive())
            .description(t.getDescription())
            .build();
    }

    private BigDecimal normalizeDeductPerDay(LeaveType.Unit unit, BigDecimal value) {
        if (unit == LeaveType.Unit.HOUR) {
            return BigDecimal.ONE.setScale(2, RoundingMode.HALF_UP);
        }
        if (value == null || value.compareTo(BigDecimal.ZERO) <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Số phép trừ mỗi ngày phải > 0");
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

    /** Hoàn lại phép khi request bị hủy/từ chối. */
    private void refundBalance(LeaveRequest request, BigDecimal hpd) {
        boolean isHour = request.getLeaveType() != null
            && request.getLeaveType().getUnit() == LeaveType.Unit.HOUR;
        BigDecimal amount = request.getRequestedAmount();
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) return;

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
            g.setUsedHours(g.getUsedHours().add(hpd));
            BigDecimal consume = BigDecimal.ONE.min(needed);
            g.setUsedDays(g.getUsedDays().add(consume));
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
}
