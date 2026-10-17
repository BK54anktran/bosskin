package com.bosskin.service;

import com.bosskin.dto.EmployeeDTO;
import com.bosskin.dto.PageResponse;
import com.bosskin.dto.UserDTO;
import com.bosskin.entity.Company;
import com.bosskin.entity.Department;
import com.bosskin.entity.Employee;
import com.bosskin.entity.Position;
import com.bosskin.entity.Role;
import com.bosskin.entity.SalaryGrade;
import com.bosskin.entity.User;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.PositionRepository;
import com.bosskin.repository.RoleRepository;
import com.bosskin.repository.SalaryGradeRepository;
import com.bosskin.repository.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;
import java.time.LocalDate;
import java.util.Set;
import java.util.HashSet;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import com.bosskin.core.SensitiveData;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class EmployeeService {

    private final EmployeeRepository employeeRepository;
    private final DepartmentRepository departmentRepository;
    private final PositionRepository positionRepository;
    private final SalaryGradeRepository salaryGradeRepository;
    private final CompanyRepository companyRepository;
    private final RoleRepository roleRepository;
    private final UserRepository userRepository;
    private final com.bosskin.repository.UserSessionRepository userSessionRepository;
    private final PasswordEncoder passwordEncoder;
    private final EmployeeCodeService employeeCodeService;
    private final DeptScopeService deptScopeService;
    private final JobHistoryService jobHistoryService;
    private final com.bosskin.repository.LaborContractRepository laborContractRepository;
    private final WorkShiftService workShiftService;

    public PageResponse<EmployeeDTO.Response> findAll(
        Long companyId, Long userId, int page, int size, String search,
        Long departmentId, Employee.Status status
    ) {
        var pageable = PageRequest.of(page, size, Sort.by("fullName").ascending());
        Set<Long> selectedDeptScope = null;
        if (departmentId != null) {
            selectedDeptScope = deptScopeService.expandDepartmentsWithDescendants(Set.of(departmentId));
            if (selectedDeptScope.isEmpty()) {
                return PageResponse.of(org.springframework.data.domain.Page.empty());
            }
        }

        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "EMPLOYEE_VIEW");
        if (!scopeIds.isEmpty()) {
            Set<Long> deptScope = scopeIds.stream()
                .filter(id -> id != null && id > 0)
                .collect(Collectors.toSet());
            if (deptScope.isEmpty()) {
                return PageResponse.of(org.springframework.data.domain.Page.empty());
            }
            if (selectedDeptScope != null) {
                Set<Long> intersection = new HashSet<>(deptScope);
                intersection.retainAll(selectedDeptScope);
                if (intersection.isEmpty()) {
                    return PageResponse.of(org.springframework.data.domain.Page.empty());
                }
                deptScope = intersection;
            }
            return PageResponse.of(
                employeeRepository.findAllWithDeptScope(companyId, deptScope, search, status, pageable)
                    .map(this::toResponse)
            );
        }

        if (selectedDeptScope != null) {
            return PageResponse.of(
                employeeRepository.findAllWithDeptScope(companyId, selectedDeptScope, search, status, pageable)
                    .map(this::toResponse)
            );
        }

        return PageResponse.of(
            employeeRepository.findAllWithFilters(companyId, search, departmentId, status, pageable)
                .map(this::toResponse)
        );
    }

    public EmployeeDTO.Response findById(Long id, Long companyId) {
        return toResponse(getOrThrow(id, companyId));
    }

    public EmployeeDTO.Response findById(Long id, Long companyId, Long userId) {
        Employee employee = getOrThrow(id, companyId);
        requireViewScope(userId, employee.getDepartment().getId());
        return toResponse(employee);
    }

    public List<EmployeeDTO.Response> findAllForShiftScope(Long companyId, Long userId) {
        return findAllForScope(companyId, userId, "SHIFT_VIEW");
    }

    /** Danh sách chọn nhân viên theo phạm vi của một quyền xem (không đòi EMPLOYEE_VIEW): chấm công, ca làm… */
    public List<EmployeeDTO.Response> findAllForScope(Long companyId, Long userId, String permission) {
        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, permission);

        if (scopeIds.isEmpty()) {
            return employeeRepository.findAllByCompanyIdFetchDepartment(companyId).stream()
                .map(this::toResponse)
                .toList();
        }

        if (scopeIds.contains(DeptScopeService.SCOPE_SELF_ONLY)) {
            return employeeRepository.findByUserIdFetch(userId)
                .filter(e -> e.getCompany().getId().equals(companyId))
                .map(this::toResponse)
                .stream()
                .toList();
        }

        Set<Long> deptScope = scopeIds.stream()
            .filter(id -> id != null && id > 0)
            .collect(Collectors.toSet());
        if (deptScope.isEmpty()) {
            return List.of();
        }
        return employeeRepository.findAllByCompanyIdAndDepartmentIdInFetchDepartment(companyId, deptScope).stream()
            .map(this::toResponse)
            .toList();
    }

    @Transactional
    public EmployeeDTO.Response create(EmployeeDTO.CreateRequest req, Long companyId, Long userId) {
        requireViewScope(userId, req.getDepartmentId());
        com.bosskin.core.PasswordPolicy.require(req.getPassword());
        if (employeeRepository.existsByEmailAndCompanyId(req.getEmail(), companyId) ||
            userRepository.existsByEmail(req.getEmail())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.email.in_use");
        }
        Company company = companyRepository.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.company.not_found"));
        // V22: email đăng nhập phải theo đuôi công ty
        com.bosskin.core.CompanyIdentity.requireEmail(company, req.getEmail());
        Department dept = departmentRepository.findByIdAndCompanyId(req.getDepartmentId(), companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.department.not_found"));
        Position pos = null;
        if (req.getPositionId() != null) {
            pos = positionRepository.findByIdAndCompanyId(req.getPositionId(), companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.position.not_found"));
            if (!pos.usableIn(req.getDepartmentId())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.position.not_in_department");
            }
        }

        Employee employee = Employee.builder()
            .company(company)
            .employeeCode(generateCode(companyId))
            .fullName(req.getFullName()).email(req.getEmail()).phone(req.getPhone())
            .gender(req.getGender()).dateOfBirth(req.getDateOfBirth()).joinDate(req.getJoinDate())
            .department(dept).position(pos)
            .address(req.getAddress()).identityCard(req.getIdentityCard())
            .bankAccount(req.getBankAccount()).bankName(req.getBankName())
            .taxCode(blankToNull(req.getTaxCode())).socialInsuranceNo(blankToNull(req.getSocialInsuranceNo()))
            .healthInsurancePlace(blankToNull(req.getHealthInsurancePlace()))
            .insuranceJoinDate(req.getInsuranceJoinDate())
            .build();
        employee = employeeRepository.save(employee);
        if (req.getManagerId() != null) {
            employee.setManager(jobHistoryService.resolveManager(employee, req.getManagerId(), companyId));
            employee = employeeRepository.save(employee);
        }
        jobHistoryService.recordHire(employee, userId);

        var role = resolveEmployeeRole(companyId);

        var user = com.bosskin.entity.User.builder()
            .email(req.getEmail())
            .password(passwordEncoder.encode(req.getPassword()))
            .mustChangePassword(true)
            .company(company)
            .employee(employee)
            .enabled(true)
            .build();
        if (role.isPresent()) {
            user.getRoles().add(role.get());
        }
        userRepository.save(user);

        return toResponse(employee);
    }

    @Transactional
    public EmployeeDTO.Response update(Long id, EmployeeDTO.UpdateRequest req, Long companyId, Long userId) {
        Employee e = getOrThrow(id, companyId);
        requireViewScope(userId, e.getDepartment().getId());
        JobHistoryService.Snapshot before = JobHistoryService.Snapshot.of(e);
        if (req.getFullName()   != null) e.setFullName(req.getFullName());
        if (req.getPhone()      != null) e.setPhone(req.getPhone());
        if (req.getGender()     != null) e.setGender(req.getGender());
        if (req.getDateOfBirth()!= null) e.setDateOfBirth(req.getDateOfBirth());
        if (req.getJoinDate()      != null) e.setJoinDate(req.getJoinDate());
        if (req.getLeaveDate()     != null) e.setLeaveDate(req.getLeaveDate());
        if (req.getStatus()        != null) e.setStatus(req.getStatus());
        if (req.getAddress()       != null) e.setAddress(req.getAddress());
        // Bước M: người không có quyền xem dữ liệu nhạy cảm gửi lại bản đã che → giữ giá trị cũ
        if (req.getIdentityCard()  != null) e.setIdentityCard(SensitiveData.incoming(e.getIdentityCard(), req.getIdentityCard()));
        if (req.getPersonalEmail() != null) e.setPersonalEmail(req.getPersonalEmail());
        if (req.getBankAccount()   != null) e.setBankAccount(SensitiveData.incoming(e.getBankAccount(), req.getBankAccount()));
        if (req.getBankName()      != null) e.setBankName(req.getBankName());
        if (req.getTaxCode()       != null) e.setTaxCode(blankToNull(SensitiveData.incoming(e.getTaxCode(), req.getTaxCode())));
        if (req.getSocialInsuranceNo() != null)
            e.setSocialInsuranceNo(blankToNull(SensitiveData.incoming(e.getSocialInsuranceNo(), req.getSocialInsuranceNo())));
        if (req.getHealthInsurancePlace() != null) e.setHealthInsurancePlace(blankToNull(req.getHealthInsurancePlace()));
        if (req.getInsuranceJoinDate()    != null) e.setInsuranceJoinDate(req.getInsuranceJoinDate());
        if (req.getDepartmentId() != null) {
            e.setDepartment(departmentRepository.findByIdAndCompanyId(req.getDepartmentId(), companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.department.not_found")));
            if (e.getPosition() != null && !e.getPosition().usableIn(e.getDepartment().getId())) {
                e.setPosition(null);
            }
        }
        if (req.getPositionId() != null) {
            Position pos = positionRepository.findByIdAndCompanyId(req.getPositionId(), companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.position.not_found"));
            if (!pos.usableIn(e.getDepartment().getId())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.position.not_in_department");
            }
            e.setPosition(pos);
        } else {
            e.setPosition(null);
        }
        if (req.getSalaryGradeId() != null) {
            SalaryGrade grade = salaryGradeRepository.findById(req.getSalaryGradeId())
                .filter(g -> g.getCompany() != null && g.getCompany().getId().equals(companyId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.salary_grade.not_found"));
            e.setSalaryGrade(grade);
        } else {
            e.setSalaryGrade(null);
        }
        if (req.getContractSalary() != null
                && (e.getContractSalary() == null || e.getContractSalary().compareTo(req.getContractSalary()) != 0)) {
            // Bước L: có hợp đồng thì lương HĐ đổi bằng hợp đồng / phụ lục
            if (laborContractRepository.managesSalary(e.getId())) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "error.contract.salary_managed_by_contract");
            }
            e.setContractSalary(req.getContractSalary());
        }
        if (req.isManagerIdPresent()) {
            e.setManager(req.getManagerId() == null ? null : jobHistoryService.resolveManager(e, req.getManagerId(), companyId));
        }
        e = employeeRepository.save(e);
        // Bước K: đổi phòng / chức vụ / bậc / quản lý → ghi mốc lịch sử công tác hiệu lực hôm nay
        jobHistoryService.recordIfChanged(e, before, userId);
        return toResponse(e);
    }

    @Transactional
    public UserDTO.SyncEmployeesResponse syncMissingUserAccounts(Long companyId, String initialPassword) {
        com.bosskin.core.PasswordPolicy.require(initialPassword);

        Company company = companyRepository.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.company.not_found"));
        List<Employee> employees = employeeRepository.findByCompanyId(companyId);
        Role employeeRole = resolveEmployeeRole(companyId).orElse(null);

        int createdCount = 0;
        int linkedCount = 0;
        int skippedCount = 0;

        for (Employee employee : employees) {
            String email = employee.getEmail();
            // V22: email không theo đuôi công ty (NV tạo trước khi có quy tắc) → không tạo / đổi tài khoản
            if (email == null || email.isBlank()
                    || !com.bosskin.core.CompanyIdentity.emailMatches(company.getDomain(), email)) {
                skippedCount++;
                continue;
            }

            User userByEmployee = userRepository.findByEmployeeId(employee.getId()).orElse(null);
            if (userByEmployee != null) {
                boolean changed = false;
                if (!email.equalsIgnoreCase(userByEmployee.getEmail())) {
                    User sameEmail = userRepository.findByEmail(email).orElse(null);
                    if (sameEmail != null && !sameEmail.getId().equals(userByEmployee.getId())) {
                        skippedCount++;
                        continue;
                    }
                    userByEmployee.setEmail(email);
                    changed = true;
                }
                if (userByEmployee.getEmployee() == null ||
                    !userByEmployee.getEmployee().getId().equals(employee.getId())) {
                    userByEmployee.setEmployee(employee);
                    changed = true;
                }
                if (!userByEmployee.isEnabled()) {
                    userByEmployee.setEnabled(true);
                    changed = true;
                }
                if (employeeRole != null && userByEmployee.getRoles().isEmpty()) {
                    userByEmployee.getRoles().add(employeeRole);
                    changed = true;
                }
                if (changed) {
                    userRepository.save(userByEmployee);
                }
                linkedCount++;
                continue;
            }

            User existing = userRepository.findByEmail(email).orElse(null);
            if (existing != null) {
                if (!existing.getCompany().getId().equals(companyId)) {
                    skippedCount++;
                    continue;
                }
                boolean changed = false;
                if (existing.getEmployee() == null) {
                    existing.setEmployee(employee);
                    changed = true;
                } else if (!existing.getEmployee().getId().equals(employee.getId())) {
                    skippedCount++;
                    continue;
                }
                if (!existing.isEnabled()) {
                    existing.setEnabled(true);
                    changed = true;
                }
                if (employeeRole != null && existing.getRoles().isEmpty()) {
                    existing.getRoles().add(employeeRole);
                    changed = true;
                }
                if (changed) {
                    userRepository.save(existing);
                }
                linkedCount++;
                continue;
            }

            User newUser = User.builder()
                .email(email)
                .password(passwordEncoder.encode(initialPassword))
                .mustChangePassword(true)
                .company(company)
                .employee(employee)
                .enabled(true)
                .build();
            if (employeeRole != null) {
                newUser.getRoles().add(employeeRole);
            }
            userRepository.save(newUser);
            createdCount++;
        }

        return UserDTO.SyncEmployeesResponse.builder()
            .createdCount(createdCount)
            .linkedCount(linkedCount)
            .skippedCount(skippedCount)
            .totalEmployees(employees.size())
            .build();
    }

    /** Gỡ thiết bị chấm công đã gắn (nhân viên đổi máy) — lần chấm sau tự gắn máy mới. */
    @Transactional
    public void unbindDevice(Long id, Long companyId) {
        Employee e = employeeRepository.findByIdAndCompanyId(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
        e.setBoundDeviceId(null);
        e.setBoundDeviceAt(null);
        employeeRepository.save(e);
    }

    /**
     * Nghỉ việc (13/10/2026): đánh dấu Đã nghỉ với ngày làm cuối, KHÔNG xoá — hồ sơ vẫn xem được (lọc "Đã nghỉ"),
     * cho đi làm lại được. Gỡ khỏi vai trò quản lý trực tiếp, khoá tài khoản + thu hồi phiên, gỡ phân ca sau ngày nghỉ
     * chưa có công. Ngày nghỉ không được trước ngày vào làm hay sau hôm nay.
     */
    @Transactional
    public EmployeeDTO.Response resign(Long id, Long companyId, Long userId, LocalDate leaveDate) {
        Employee e = getOrThrow(id, companyId);
        requireViewScope(userId, e.getDepartment().getId());
        LocalDate last = leaveDate != null ? leaveDate : LocalDate.now();
        if (last.isAfter(LocalDate.now())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.employee.leave_date_future");
        }
        if (e.getJoinDate() != null && last.isBefore(e.getJoinDate())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.employee.leave_before_join");
        }
        e.setStatus(Employee.Status.INACTIVE);
        e.setLeaveDate(last);
        employeeRepository.save(e);
        employeeRepository.clearManager(e.getId());
        lockAccount(e.getId());
        workShiftService.removeAssignmentsAfter(companyId, e.getId(), last);
        return toResponse(e);
    }

    /** Cho nhân viên đã nghỉ đi làm lại: Đang làm, bỏ ngày nghỉ, mở lại tài khoản (quản lý trực tiếp không tự gán lại). */
    @Transactional
    public EmployeeDTO.Response reinstate(Long id, Long companyId, Long userId) {
        Employee e = getOrThrow(id, companyId);
        requireViewScope(userId, e.getDepartment().getId());
        if (e.getStatus() != Employee.Status.INACTIVE) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.employee.not_resigned");
        }
        e.setStatus(Employee.Status.ACTIVE);
        e.setLeaveDate(null);
        employeeRepository.save(e);
        userRepository.findByEmployeeId(e.getId()).ifPresent(u -> {
            u.setEnabled(true);
            userRepository.save(u);
        });
        return toResponse(e);
    }

    private void lockAccount(Long employeeId) {
        userRepository.findByEmployeeId(employeeId).ifPresent(u -> {
            u.setEnabled(false);
            userRepository.save(u);
            userSessionRepository.revokeAllByUserId(u.getId());
        });
    }

    /** Xoá hẳn (ẩn khỏi mọi danh sách) — chỉ dành cho hồ sơ tạo nhầm; nghỉ việc dùng {@link #resign}. */
    @Transactional
    public void delete(Long id, Long companyId, Long userId) {
        Employee e = getOrThrow(id, companyId);
        requireViewScope(userId, e.getDepartment().getId());
        e.setStatus(Employee.Status.INACTIVE);
        if (e.getLeaveDate() == null) {
            e.setLeaveDate(LocalDate.now());
        }
        employeeRepository.save(e);
        employeeRepository.delete(e);
        // Bước K: cấp dưới của người nghỉ không còn quản lý trực tiếp
        employeeRepository.clearManager(e.getId());

        // D4: nhân viên đã xoá không được đăng nhập tiếp — khoá tài khoản và thu hồi phiên
        lockAccount(e.getId());
    }

    private void requireViewScope(Long userId, Long deptId) {
        Set<Long> scope = deptScopeService.resolvedScopes(userId, "EMPLOYEE_VIEW");
        if (!scope.isEmpty() && !scope.contains(deptId))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.department_scope");
    }

    private java.util.Optional<Role> resolveEmployeeRole(Long companyId) {
        // Chỉ vai trò được đánh dấu mặc định. Không còn tìm theo tên để tránh nhầm sang vai trò khác.
        return roleRepository.findFirstByCompanyIdAndIsDefaultTrue(companyId);
    }

    private Employee getOrThrow(Long id, Long companyId) {
        return employeeRepository.findByIdAndCompanyId(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
    }

    private String generateCode(Long companyId) {
        return employeeCodeService.next(companyId);
    }

    private EmployeeDTO.Response toResponse(Employee e) {
        return EmployeeDTO.Response.builder()
            .id(e.getId()).employeeCode(e.getEmployeeCode())
            .fullName(e.getFullName()).email(e.getEmail()).phone(e.getPhone())
            .personalEmail(e.getPersonalEmail())
            .avatar(e.getAvatar()).gender(e.getGender())
            .dateOfBirth(e.getDateOfBirth()).joinDate(e.getJoinDate()).leaveDate(e.getLeaveDate())
            .deviceBound(e.getBoundDeviceId() != null).boundDeviceAt(e.getBoundDeviceAt())
            .status(e.getStatus())
            .departmentId(e.getDepartment().getId()).departmentName(e.getDepartment().getName())
            .positionId(e.getPosition() != null ? e.getPosition().getId() : null)
            .positionName(e.getPosition() != null ? e.getPosition().getName() : null)
            .salaryGradeId(e.getSalaryGrade() != null ? e.getSalaryGrade().getId() : null)
            .salaryGradeCode(e.getSalaryGrade() != null ? e.getSalaryGrade().getCode() : null)
            .salaryGradeName(e.getSalaryGrade() != null ? e.getSalaryGrade().getName() : null)
            .managerId(e.getManager() != null ? e.getManager().getId() : null)
            .managerName(e.getManager() != null ? e.getManager().getFullName() : null)
            .address(e.getAddress())
            .identityCard(SensitiveData.forViewer(e.getIdentityCard()))
            .bankAccount(SensitiveData.forViewer(e.getBankAccount())).bankName(e.getBankName())
            .taxCode(SensitiveData.forViewer(e.getTaxCode()))
            .socialInsuranceNo(SensitiveData.forViewer(e.getSocialInsuranceNo()))
            .healthInsurancePlace(e.getHealthInsurancePlace()).insuranceJoinDate(e.getInsuranceJoinDate())
            .contractSalary(e.getContractSalary()).createdAt(e.getCreatedAt())
            .build();
    }

    private static String blankToNull(String v) {
        return v == null || v.isBlank() ? null : v.trim();
    }
}
